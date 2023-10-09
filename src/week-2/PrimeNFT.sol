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
        for (uint256 i = 1; i < 21; ++i) {
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

        unchecked {
            // find token ids owned by account
            for (uint256 i; i < balance; ++i) {
                nfts[i] = nft.tokenOfOwnerByIndex(account, i);
            }

            for (uint256 i; i < nfts.length; ++i) {
                if (isPrime(nfts[i])) ++count;
            }
        }
    }

    /**
     * @dev a primality check for 999_999_937 (largest prime below 1B) consumes 749,610 gas
     * a primality check for 10_000_000_019 (smallest prime above 10B) consumes 2,367,819 gas
     * @param n a whole number
     * @return status bool whether n is prime
     */
    function isPrime(uint256 n) public pure returns (bool status) {
        if (n <= 1) return status = false;
        if (n <= 3) return status = true;

        // return false if n is divisible by 2 or 3
        unchecked {
            if (n & 1 == 0 || n % 3 == 0) return status = false;
        }

        uint256 sqrtN = Math.sqrt(n);
        // i is always less than sqrtN so it won't overflow
        unchecked {
            for (uint256 i = 5; i <= sqrtN; i += 6) {
                /**
                 * check for i and i + 2
                 * skip i + 4 because it's always a multiple of 3
                 */
                if (n % i == 0) return status = false;
                if (n % (i + 2) == 0) return status = false;
            }
        }

        return status = true;
    }
}
