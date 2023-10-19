// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PairERC20 is ERC20 {
    constructor() ERC20("Uniswap V2", "UNI-V2") { }
}
