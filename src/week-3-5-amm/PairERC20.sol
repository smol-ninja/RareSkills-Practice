// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PairERC20  is ERC20 {
    constructor() ERC20("Uniswap V2", "UNI-V2") { }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {

    }

    function PERMIT_TYPEHASH() external view returns (bytes32) {

    }

    function nonces(address owner) external view returns (uint) {

    }

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {

    }

}