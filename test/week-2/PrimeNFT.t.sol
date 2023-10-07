// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Test } from "forge-std/Test.sol";

import { EnumerableNFT, Prime } from "../../src/week-2/PrimeNFT.sol";

contract PrimeNFTTest is Test {
    uint32 private constant LARGEST_PRIME_BELOW_1B = 999_999_937;
    uint8[] private first25Primes =
        [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97];

    EnumerableNFT private nft;
    address private minter = makeAddr("minter");
    Prime private prime = new Prime();

    function setUp() public {
        vm.prank(minter);
        nft = new EnumerableNFT();
    }

    function test_Minting() public {
        assertEq(nft.totalSupply(), 20);

        for (uint256 i = 1; i < 21; ++i) {
            assertEq(nft.ownerOf(i), minter);
        }
    }

    function test_FindPrimeNFTs() public {
        uint256 primeNfts = prime.findPrimeNFTs(minter, nft);
        assertEq(primeNfts, 8);
    }

    function test_isPrime() public {
        bool status;
        bool found;

        // check for numbers 0..100
        for (uint256 i; i < 100; ++i) {
            found = false;
            status = prime.isPrime(i);
            for (uint256 j; j < 25; ++j) {
                if (first25Primes[j] == i) {
                    assertEq(status, true);
                    found = true;
                    break;
                }
            }
            if (found) continue;
            assertEq(status, false);
        }

        // check for a pseudoprime
        status = prime.isPrime(60_787);
        assertEq(status, false);

        // check for a very large prime
        status = prime.isPrime(LARGEST_PRIME_BELOW_1B);
        assertEq(status, true);
    }
}
