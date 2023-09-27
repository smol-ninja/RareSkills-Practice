// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Sanction is ERC20, Ownable {
    // @dev map to store sanctioned addresses
    mapping(address owner => bool status) private _sanctioned;

    // @dev gas efficient over `require`
    error AddressIsSanctioned(address);

    constructor() ERC20("Token with Sanctions", "SNCT") Ownable() { }

    function addSanction(address owner_) external onlyOwner {
        _sanctioned[owner_] = true;
    }

    function removeSanction(address owner_) external onlyOwner {
        _sanctioned[owner_] = false;
    }

    function hasSanction(address owner_) external view returns (bool) {
        return _sanctioned[owner_];
    }

    // @dev ERC20 hook that is called before any transfer of tokens
    // @revert if either `to` or `from` is sanctioned
    function _beforeTokenTransfer(address from, address to, uint256) internal view override {
        if (_sanctioned[from]) {
            revert AddressIsSanctioned(from);
        }

        if (_sanctioned[to]) {
            revert AddressIsSanctioned(to);
        }
    }
}
