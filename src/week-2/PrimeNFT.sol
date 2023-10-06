// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC721Enumerable } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract EnumerableNFT is ERC721Enumerable {
    /**
     * @dev we could also use `ERC721Consecutive` to batch mint tokens during construction
     */
    constructor() ERC721("EnumerableNFT", "ENFT") {
        for (uint8 i = 1; i < 21; ++i) {
            _safeMint(msg.sender, i);
        }
    }
}

contract Prime {
    /**
     * @param account address of the user
     * @param nft address of NFT contract to check IDs for
     * @return count of the NFT tokens IDs which are prime numbers
     */
    function findPrimeNFTs(address account, EnumerableNFT nft) public view returns (uint256 count) {
        uint256 balance = nft.balanceOf(account);
        uint256[] memory nfts = new uint256[](balance);

        // find token ids owned by account
        for (uint256 i; i < balance; ++i) {
            nfts[i] = nft.tokenOfOwnerByIndex(account, i);
        }

        unchecked {
            for (uint256 i; i < nfts.length; ++i) {
                if (isPrime(nfts[i])) ++count;
            }
        }
    }

    /**
     * @dev a primality check for 999_999_937 (largest prime below 1B) consumes 2,783,662 gas
     * a primality check for 10_000_000_019 (smallest prime above 10B) consumes 8,800,903 gas
     * @param n a whole number
     * @return isPrime_ bool whether n is prime
     */
    function isPrime(uint256 n) public pure returns (bool) {
        if (n < 2) return false;
        if (n < 4) return true;

        unchecked {
            if (n % 2 == 0 || n % 3 == 0) return false;
        }

        uint256 sqrtN = Math.sqrt(n);
        unchecked {
            for (uint256 i = 5; i <= sqrtN; ++i) {
                if (n % i == 0) return false;
            }
        }

        return true;
    }
}
