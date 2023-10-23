// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GodMode is ERC20 {
    error Unauthorized();

    address private immutable _god;

    // @param god_ the special address that can move token between two any addresses
    constructor(address god_) ERC20("Token with God mode", "GODT") {
        _god = god_;
    }

    modifier onlyGod() {
        if (msg.sender != _god) revert Unauthorized();
        _;
    }

    // @notice a function to transfer tokens between addresses by the special address
    function transferByGod(address from, address to, uint256 amount) external onlyGod {
        _transfer(from, to, amount);
    }
}
