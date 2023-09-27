// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Escrow {
    using SafeERC20 for IERC20;

    event NewDeposit(address indexed recipient, uint256 id);

    // @param token erc20 that buyer deposits
    // @param amount of erc20 that buyer deposits
    // @timestamp when buyer deposits. Requires to keep track of cool down period for seller
    struct TimeLock {
        IERC20 token;
        uint256 amount;
        uint256 timestamp;
    }

    uint256 private constant THREE_DAYS = 3 days;

    // @dev size of TimeLock array is always increasing
    mapping(address recipient => TimeLock[] tls) private _withdrawables;

    // @notice once a buyer has entered into escrow, token can only be withdrawn by the seller
    // @dev return id is not unique but (recipient, id) is.
    // @param seller_ the address of the seller who is allowed to withdraw tokens after 3 days
    // @param token_ erc20 token that buyer deposits
    // @param amount_ amount of erc20 token that buyer deposits
    // @return id which is length of the escrows array for a given seller. id is not unique.
    function enterEscrow(address seller_, IERC20 token_, uint256 amount_) external returns (uint256 id) {
        token_.safeTransferFrom(msg.sender, address(this), amount_);

        TimeLock memory tl;
        tl.token = token_;
        tl.amount = amount_;
        tl.timestamp = block.timestamp;
        _withdrawables[seller_].push(tl);

        id = _withdrawables[seller_].length - 1;

        emit NewDeposit(seller_, id);
    }

    // @notice seller can withdraw token using id only after 3 days have passed
    // @revert if 3 days have not been passed
    function settleForId(uint256 id_) external {
        TimeLock memory tl = _withdrawables[msg.sender][id_];
        require(block.timestamp >= tl.timestamp + THREE_DAYS, "cant withdraw");

        // sets amount to 0 to prevent double spends
        _withdrawables[msg.sender][id_].amount = 0;

        tl.token.safeTransfer(msg.sender, tl.amount);
    }

    // @notice scan and withdraw for all available IDs for a msg.sender
    // @dev this function ignores IDs for which either amount is 0 or 3 days have not been passed.
    function settleForAllIds() external {
        TimeLock[] memory tls = _withdrawables[msg.sender];

        uint256 len = tls.length;

        // loop over all IDs
        for (uint256 i; i < len; i++) {
            if (block.timestamp >= tls[i].timestamp + THREE_DAYS && tls[i].amount > 0) {
                // sets amount to 0 to prevent double spends
                _withdrawables[msg.sender][i].amount = 0;
                tls[i].token.safeTransfer(msg.sender, tls[i].amount);
            }
        }
    }
}
