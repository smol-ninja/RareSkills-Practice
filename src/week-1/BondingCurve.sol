// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC1820Registry } from "@openzeppelin/contracts/utils/introspection/IERC1820Registry.sol";
import { IERC1363Receiver } from "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";
import { IERC1363Spender } from "@openzeppelin/contracts/interfaces/IERC1363Spender.sol";

// @notice BojackToken implements ERC20 and adds control over mint and burn by owner
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

    IERC1820Registry internal constant _ERC1820_REGISTRY = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    BojackToken private immutable _token;

    // @notice RATIO = supply / price
    uint256 private constant RATIO = 100;
    // @notice set starting price to be 0, supports decimal prices
    uint256 private _currentPrice;

    constructor() {
        _token = new BojackToken("Bojack", "BOJ");

        // register interface for ERC777TokensRecipient
        _ERC1820_REGISTRY.setInterfaceImplementer(address(this), keccak256("ERC777TokensRecipient"), address(this));
    }

    function getTokenAddress() external view returns (address tokenAddress) {
        tokenAddress = address(_token);
    }

    // @return the current price of the token from the Bonding curve
    function getCurrentPrice() external view returns (uint256) {
        return _currentPrice;
    }

    // @dev this function is vulenerable to sandwich attack because of how bonding curve works.
    // @param TODO: maxAcceptablePrice the maximum acceptable price to users to mitigate risk of sandwich attacks
    // @param depositTokenAddress an ERC20 token that user wants to buy with
    // @param depositAmount amount of ERC20 token
    function buy(uint256 depositAmount, address depositTokenAddress) external {
        // transfer the token from sender address to sale manager address
        IERC20(depositTokenAddress).safeTransferFrom(msg.sender, address(this), depositAmount);

        _buy(msg.sender, depositAmount);
    }

    // @param depositTokenAddress an ERC20 token that user wants to buy with
    // @param depositAmount amount of ERC20 token
    // @param sender the address of the buyer
    function _buy(address sender, uint256 depositAmount) private {
        // loading _currentPrice in memory from storage
        uint256 curPrice = _currentPrice;

        uint256 newPrice = _calculateNewPrice(depositAmount, curPrice);

        uint256 transferAmount = (newPrice - curPrice) * RATIO;
        _currentPrice = newPrice;

        // mint and send BOJ tokens to buyer address
        _token.mint(sender, transferAmount);
    }

    // @return the average price of BOJ token that user would receive
    function calculateAvgPrice(uint256 depositAmount) external view returns (uint256 avgPrice) {
        // loading _currentPrice in memory from storage
        uint256 curPrice = _currentPrice;
        uint256 newPrice = _calculateNewPrice(depositAmount, curPrice);

        avgPrice = Math.average(newPrice, curPrice);
    }

    // @notice calculate the new price of the BOJ token
    // @return the new price of the BOJ token
    function _calculateNewPrice(uint256 depositAmount, uint256 curPrice) private pure returns (uint256 newPrice) {
        // newPrice = sqrt(curPrice^2 + 2 * m * depositAmount) where m = 1 / RATIO
        newPrice = Math.sqrt(curPrice * curPrice + 2e18 * depositAmount / RATIO);
    }

    // @dev implementation for ERC777TokensRecipient interface
    function tokensReceived(address, address from, address, uint256 amount, bytes calldata, bytes calldata) external {
        _buy(from, amount);
    }

    // @notice IERC1363Receiver interface to support transferAndCall
    // @dev token transfer to this address would trigger this function. msg.sender is always token address.
    function onTransferReceived(
        address,
        address from,
        uint256 amount,
        bytes calldata
    )
        external
        returns (bytes4 _selector)
    {
        _buy(from, amount);

        _selector = IERC1363Receiver.onTransferReceived.selector;
    }

    // @notice IERC1363Receiver interface to support approveAndCall
    // @dev msg.sender is always token address.
    function onApprovalReceived(address owner, uint256 amount, bytes calldata) external returns (bytes4 _selector) {
        IERC20(msg.sender).safeTransferFrom(owner, address(this), amount);
        _buy(owner, amount);

        _selector = IERC1363Spender.onApprovalReceived.selector;
    }

    // @notice function to sell BOJ tokens through bonding curve
    // @param amount. number of BOJ tokens that user wants to sell, in 1e18
    // @param tokenToWithdraw, ERC20 token that user chooses to receive
    function sell(uint256 amount, address tokenToWithdraw) external {
        // loading _currentPrice in memory from storage
        uint256 curPrice = _currentPrice;

        // p1 = p2 - m * (s2 - s1)
        uint256 newPrice = curPrice - (amount / RATIO);

        // tokensOut = area under the curve = avg(p1, p2) * amount
        uint256 tokensOutValue = amount * Math.average(newPrice, curPrice) / 1e18;

        _currentPrice = newPrice;
        _token.burn(msg.sender, amount);

        IERC20(tokenToWithdraw).safeTransfer(msg.sender, tokensOutValue);
    }
}
