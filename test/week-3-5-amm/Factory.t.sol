// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Test } from "forge-std/Test.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { Factory } from "../../src/week-3-5-amm/Factory.sol";
import { Pair } from "../../src/week-3-5-amm/Pair.sol";

contract FactoryTest is Test {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    error ZeroAddress();

    Factory private factory = new Factory();
    ERC20 private dai = new ERC20("DAI Token", "DAI");
    ERC20 private mkr = new ERC20("Maker Token", "MKR");

    function _computeAddress(address token0, address token1) private view returns (address pair) {
        if (token1 < token0) {
            (token0, token1) = (token1, token0);
        }
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"FF",
                            address(factory),
                            hex"597ff892197fdc5c0ef4e2ee49fc7c4e990dfc72fae590dd8a6ab49c343cdf4c",
                            keccak256(abi.encodePacked(type(Pair).creationCode, abi.encode(token0, token1)))
                        )
                    )
                )
            )
        );
    }

    function testFuzz_CreatePair(ERC20 token0, ERC20 token1) public {
        ERC20 t1 = token0;
        ERC20 t2 = token1;
        if (token1 < token0) {
            (t1, t2) = (token1, token0);
        }

        // fail if any token is a zero address
        if (address(token0) == address(0) || address(token1) == address(0)) {
            vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
            factory.createPair(address(token0), address(token1));
        } else {
            // test if pair is created successfully
            vm.expectEmit(true, true, false, true);
            emit PairCreated(address(t1), address(t2), _computeAddress(address(token0), address(token1)), 1);
            factory.createPair(address(token0), address(token1));

            // fail if the user tries to create the same pair again
            vm.expectRevert();
            factory.createPair(address(token0), address(token1));

            // // fail if pair user tries to create the same pair again but in reverse order
            vm.expectRevert();
            factory.createPair(address(token1), address(token0));
        }
    }

    modifier create1000Pairs() {
        ERC20 token0;
        ERC20 token1;
        for (uint256 i; i < 1000; ++i) {
            if (i == 500) {
                factory.createPair(address(dai), address(mkr));
                continue;
            }
            token0 = new ERC20("Random Token", "RT");
            token1 = new ERC20("Random Token", "RT");
            factory.createPair(address(token0), address(token1));
        }
        _;
    }

    function test_GetPair() public create1000Pairs {
        // return non-zero address for valid pair
        address pair = factory.getPair(address(dai), address(mkr));
        assertEq(pair, _computeAddress(address(dai), address(mkr)));

        // return zero address for valid pair
        ERC20 token0 = new ERC20("Random Token", "RT");
        ERC20 token1 = new ERC20("Random Token", "RT");
        pair = factory.getPair(address(token0), address(token1));
        assertEq(pair, address(0));
    }

    function test_AllPairs() public create1000Pairs {
        address pair = factory.allPairs(500);
        assertEq(pair, _computeAddress(address(dai), address(mkr)));
    }

    function test_AllPairsLength() public create1000Pairs {
        uint256 len = factory.allPairsLength();
        assertEq(len, 1000);
    }
}
