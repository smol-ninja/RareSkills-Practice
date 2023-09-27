// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Escrow {
    using SafeERC20 for IERC20;

    event NewDeposit(address indexed recipient, uint256 id);

    struct TimeLock {
        IERC20 token;
        uint256 amount;
        uint256 timestamp;
    }

    uint256 private constant THREE_DAYS = 3 days;
    mapping(address recipient => TimeLock[] tls) private _withdrawables;

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

    function settleForId(uint256 id_) external {
        TimeLock memory tl = _withdrawables[msg.sender][id_];

        require(block.timestamp >= tl.timestamp + THREE_DAYS, "cant withdraw");

        _withdrawables[msg.sender][id_].amount = 0;
        tl.token.safeTransfer(msg.sender, tl.amount);
    }

    function settleForAllIds() external {
        TimeLock[] memory tls = _withdrawables[msg.sender];

        uint256 len = tls.length;
        for (uint256 i; i < len; i++) {
            if (block.timestamp >= tls[i].timestamp + THREE_DAYS && tls[i].amount > 0) {
                _withdrawables[msg.sender][i].amount = 0;
                tls[i].token.safeTransfer(msg.sender, tls[i].amount);
            }
        }
    }
}
