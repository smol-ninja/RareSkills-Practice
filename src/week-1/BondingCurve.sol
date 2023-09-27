// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC1820Registry } from "@openzeppelin/contracts/utils/introspection/IERC1820Registry.sol";
import { IERC1363Receiver } from "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";
import { IERC1363Spender } from "@openzeppelin/contracts/interfaces/IERC1363Spender.sol";

contract BojackToken is ERC20 {
    address private _saleManager;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        _saleManager = _msgSender();
    }

    modifier onlySaleManager() {
        require(_msgSender() == _saleManager, "Unauthorized");
        _;
    }

    function mint(address recipient, uint256 amount) public onlySaleManager {
        _mint(recipient, amount);
    }

    function burn(address account, uint256 amount) public onlySaleManager {
        _burn(account, amount);
    }

    function transferManager(address newManager) public onlySaleManager {
        _saleManager = newManager;
    }
}

contract TokenSaleManager {
    using SafeERC20 for BojackToken;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IERC1820Registry internal constant _ERC1820_REGISTRY = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    BojackToken private immutable _token;

    // @notice for 100 tokens minted, price only moves by $1
    uint256 private constant RATIO = 100e18;
    // @notice set starting price to be $0
    uint256 private _currentPrice = 0;

    constructor() {
        _token = new BojackToken("Bojack", "BOJ");

        // register interface for ERC777TokensRecipient
        _ERC1820_REGISTRY.setInterfaceImplementer(address(this), keccak256("ERC777TokensRecipient"), address(this));
    }

    function getTokenAddress() external view returns (address tokenAddress) {
        tokenAddress = address(_token);
    }

    function getCurrentPrice() external view returns (uint256) {
        return _currentPrice;
    }

    // @notice this function is vulnerable to sandwich attack. To mitigate that risk
    // an acceptable slippage can be added as a parameter to minize the loss
    // if expected - actual is more than slippage, revert
    function buy(uint256 depositAmount, address depositTokenAddress) external {
        // transfer the token from sender address to sale manager address
        IERC20(depositTokenAddress).safeTransferFrom(msg.sender, address(this), depositAmount);

        _buy(msg.sender, depositAmount, depositTokenAddress);
    }

    function _buy(address sender, uint256 depositAmount, address depositTokenAddress) private {
        // loadin _currentPrice in memory from storage
        uint256 curPrice = _currentPrice;

        uint256 newPrice = _calculateNewPrice(depositAmount, depositTokenAddress, curPrice);
        uint256 transferAmount = newPrice.sub(curPrice).mul(RATIO);
        _currentPrice = newPrice;

        // mint and send BOJ tokens to buyer address
        _token.mint(sender, transferAmount);
    }

    function calculateAvgPrice(uint256 depositAmount, address depositTokenAddress) external view returns (uint256) {
        // loadin _currentPrice in memory from storage
        uint256 curPrice = _currentPrice;
        uint256 newPrice = _calculateNewPrice(depositAmount, depositTokenAddress, curPrice);
        return Math.average(newPrice, curPrice);
    }

    function getOraclePrice(address) private pure returns (uint256) {
        return 1;
    }

    function _calculateNewPrice(
        uint256 depositAmount,
        address depositTokenAddress,
        uint256 curPrice
    )
        private
        pure
        returns (uint256 newPrice)
    {
        uint256 tokenValueIn = depositAmount.mul(getOraclePrice(depositTokenAddress));

        // calculate newPrice using bonding curve.
        // newPrice = sqrt(curPrice^2 + 2 * RATIO * tokenValueIn)
        newPrice = Math.sqrt(curPrice.mul(curPrice).add(tokenValueIn.mul(2).div(RATIO)));
    }

    // @dev function implementation for ERC777TokensRecipient interface
    function tokensReceived(address, address from, address, uint256 amount, bytes calldata, bytes calldata) external {
        _buy(from, amount, msg.sender);
    }

    // IERC1363Receiver interface to support transferAndCall
    function onTransferReceived(address, address from, uint256 amount, bytes calldata) external returns (bytes4) {
        _buy(from, amount, msg.sender);

        return IERC1363Receiver.onTransferReceived.selector;
    }

    // IERC1363Receiver interface to support approveAndCall
    function onApprovalReceived(address owner, uint256 amount, bytes calldata) external returns (bytes4) {
        // transfer the token from sender address to sale manager address
        IERC20(msg.sender).safeTransferFrom(owner, address(this), amount);
        _buy(owner, amount, msg.sender);

        return IERC1363Spender.onApprovalReceived.selector;
    }

    function sell(uint256 amount, address tokenToWithdraw) external {
        // loadin _currentPrice in memory from storage
        uint256 curPrice = _currentPrice;

        // p1 = p2 - m * (s2 - s1)
        uint256 newPrice = curPrice.sub(amount.div(RATIO));

        // tokensOut = area under the curve = avg(p1, p2) * amount
        uint256 tokensOutValue = Math.average(newPrice.mul(amount), curPrice.mul(amount));
        uint256 tokensOut = tokensOutValue.div(getOraclePrice(tokenToWithdraw));

        _currentPrice = newPrice;
        _token.burn(msg.sender, amount);

        IERC20(tokenToWithdraw).transfer(msg.sender, tokensOut);
    }
}
