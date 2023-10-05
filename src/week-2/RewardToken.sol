// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @dev deploying StakingContract will automatically deploy this token 
 */
contract RewardToken is ERC20 {
    address public immutable stakingContract;

    // error names
    error Unauthorized();

    constructor() ERC20("RewardToken", "RT") {
        stakingContract = msg.sender;
     }

    modifier isStakingContract() {
        if (msg.sender != stakingContract) revert Unauthorized();
        _;
    }

    function mint(address account, uint256 amount) public isStakingContract {
        _mint(account, amount);
    }
}