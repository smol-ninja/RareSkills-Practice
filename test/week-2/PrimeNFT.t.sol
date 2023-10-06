// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Test } from "forge-std/Test.sol";

import { EnumerableNFT, Prime } from "../../src/week-2/PrimeNFT.sol";

contract PrimeNFTTest is Test {
    uint32 private constant LARGEST_PRIME_BELOW_1B = 999_999_937;

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
        // check for 1
        bool status = prime.isPrime(1);
        assertEq(status, false);

        // check for 49
        status = prime.isPrime(49);
        assertEq(status, false);

        // check for even
        status = prime.isPrime(10_000);
        assertEq(status, false);

        // check for a very large prime
        status = prime.isPrime(LARGEST_PRIME_BELOW_1B);
        assertEq(status, true);
    }
}
