// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Test } from "forge-std/Test.sol";

import { Dex, SwappableToken, Attacker } from "../../src/week-6-7/EthernautDex.sol";

contract DexAttackTest is Test {
    uint256 private constant DEX_BALANCE = 100;
    uint256 private constant USER_BALANCE = 10;
    uint256 private constant SUPPLY = DEX_BALANCE + USER_BALANCE;

    Dex private dex = new Dex();
    SwappableToken private token1 = new SwappableToken(address(dex), "token 1", "token1", SUPPLY);
    SwappableToken private token2 = new SwappableToken(address(dex), "token 2", "token2", SUPPLY);
    Attacker private attacker = new Attacker(dex, token1, token2);

    address private user = makeAddr("user");

    function setUp() public {
        // set tokens
        dex.setTokens(address(token1), address(token2));
        // add initial liquidity to the dex
        token1.transfer(address(dex), DEX_BALANCE);
        token2.transfer(address(dex), DEX_BALANCE);
        // transfer 10 tokens to the user
        token1.transfer(user, USER_BALANCE);
        token2.transfer(user, USER_BALANCE);

        vm.prank(user);
        dex.approve(address(attacker), USER_BALANCE);
    }

    function test_Attack() public {
        assertEq(token1.balanceOf(address(dex)), DEX_BALANCE);
        assertEq(token2.balanceOf(address(dex)), DEX_BALANCE);
        assertEq(token1.balanceOf(user), USER_BALANCE);
        assertEq(token2.balanceOf(user), USER_BALANCE);

        vm.prank(user);
        attacker.attack(USER_BALANCE);

        assertTrue(token1.balanceOf(address(dex)) == 0 || token2.balanceOf(address(dex)) == 0);
        assertTrue(token1.balanceOf(user) == SUPPLY || token2.balanceOf(user) == SUPPLY);

        if (token2.balanceOf(address(dex)) <= token1.balanceOf(address(dex))) {
            uint256 swapPrice = dex.getSwapPrice(address(token1), address(token2), 1);
            assertEq(swapPrice, 0);
        } else {
            vm.expectRevert();
            dex.getSwapPrice(address(token1), address(token2), 1);
        }
    }
}
