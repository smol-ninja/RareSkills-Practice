// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GodMode is ERC20 {
    address private immutable _god;

    error CallerNotGod();

    constructor(address god_) ERC20("Token with God mode", "GODT") {
        _god = god_;
    }

    modifier onlyGod() {
        require(msg.sender == _god, "only God");
        _;
    }

    function transferByGod(address from, address to, uint256 amount) external onlyGod {
        _transfer(from, to, amount);
    }
}
