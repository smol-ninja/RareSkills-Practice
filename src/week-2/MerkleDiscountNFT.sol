// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC2981 } from "@openzeppelin/contracts/token/common/ERC2981.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { BitMaps } from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MerkleDiscountNFT is Ownable2Step, ERC721, ERC2981 {
    uint8 public constant MAX_SUPPLY = 20;
    uint8 private constant _DEFAULT_ROYALTY = 250; // 2.5%
    uint8 public totalSupply;
    uint64 public constant MINT_PRICE = 0.1 ether;
    uint64 public constant DISCOUNTED_PRICE = 0.08 ether; // 20% discount
    bytes32 public immutable merkleRoot;
    BitMaps.BitMap private _bitmap;

    // event names
    event Minted(address, uint256);

    // error names
    error MintingClosed();
    error NotEnoughEtherSent();
    error AlreadyMinted();
    error FailedToTransferEther();
    error InvalidProof();

    /**
     * @param merkleRoot_ root node of merkle tree containing addresses eligible for discount
     */
    constructor(bytes32 merkleRoot_) ERC721("MerkleDiscountNFT", "MDNFT") Ownable2Step() {
        _setDefaultRoyalty(owner(), _DEFAULT_ROYALTY);
        merkleRoot = merkleRoot_;
    }

    /**
     * @dev See {ERC2981-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice anybody can mint NFT until supply is reached
     * @dev any excess ether gets returned to the msg.sender
     */
    function mint() external payable {
        if (totalSupply >= MAX_SUPPLY) revert MintingClosed();
        if (msg.value < MINT_PRICE) revert NotEnoughEtherSent();

        unchecked {
            totalSupply++;
        }
        _safeMint(msg.sender, totalSupply);

        // return excess ether
        if (msg.value > MINT_PRICE) {
            unchecked {
                (bool status,) = payable(msg.sender).call{ value: msg.value - MINT_PRICE }("");
                if (!status) revert FailedToTransferEther();
            }
        }

        emit Minted(msg.sender, totalSupply);
    }

    /**
     * @param index to look in BitMap
     * @return result whether the bit at `index` is set.
     */
    function _hasMinted(uint256 index) private view returns (bool result) {
        result = BitMaps.get(_bitmap, index);
    }

    /**
     * @notice only whitelisted address can call this function
     * @param index index to look for in BitMap
     * @param proof MerkleProof generated for user using address and index values
     */
    function mintWhitelisted(uint256 index, bytes32[] calldata proof) external payable {
        if (totalSupply >= MAX_SUPPLY) revert MintingClosed();
        if (msg.value < DISCOUNTED_PRICE) revert NotEnoughEtherSent();
        if (_hasMinted(index)) revert AlreadyMinted();

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, index))));
        if (!MerkleProof.verify(proof, merkleRoot, leaf)) revert InvalidProof();

        // set bit at `index` in BitMap
        BitMaps.set(_bitmap, index);

        unchecked {
            totalSupply++;
        }
        _safeMint(msg.sender, totalSupply);

        // return excess ether
        if (msg.value > DISCOUNTED_PRICE) {
            unchecked {
                (bool status,) = payable(msg.sender).call{ value: msg.value - DISCOUNTED_PRICE }("");
                if (!status) revert FailedToTransferEther();
            }
        }

        emit Minted(msg.sender, totalSupply);
    }

    /**
     * @dev allow owner of this contract to withdraw ether
     */
    function withdrawFunds() external onlyOwner {
        // transfer ether using call
        (bool sent,) = payable(owner()).call{ value: address(this).balance }("");
        if (!sent) revert FailedToTransferEther();
    }
}
