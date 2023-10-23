// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Test } from "forge-std/Test.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { Escrow } from "../../src/week-1/Escrow.sol";

contract EscrowTest is Test {
    event NewDeposit(address indexed recipient, uint256 id);

    Escrow private escrow;
    address private buyer = makeAddr("buyer");
    address private seller = makeAddr("seller");
    ERC20 private testToken = new ERC20("Test Token", "TT");

    function setUp() public {
        escrow = new Escrow();
        deal(address(testToken), buyer, 100e18);
        vm.prank(buyer);
        testToken.approve(address(escrow), type(uint256).max);
    }

    function testFuzz_EnterEscrow(uint256 amount) public {
        vm.assume(amount <= 100e18);

        vm.startPrank(buyer);
        if (amount == 0) {
            vm.expectRevert(bytes("0 amount"));
            escrow.enterEscrow(seller, testToken, amount);
        } else {
            vm.expectEmit(true, false, false, true);
            emit NewDeposit(seller, 0);
            escrow.enterEscrow(seller, testToken, amount);
            assertEq(testToken.balanceOf(buyer), 100e18 - amount);
            assertEq(testToken.balanceOf(address(escrow)), amount);
        }
        vm.stopPrank();
    }

    function testFuzz_SettleForId(uint256 amount, uint32 timePassed) public {
        vm.assume(timePassed <= 4 days && amount > 0);

        testFuzz_EnterEscrow(amount);
        vm.warp(block.timestamp + timePassed);

        vm.startPrank(seller);
        if (timePassed < 3 days) {
            vm.expectRevert(bytes("cant withdraw"));
            escrow.settleForId(0);
        } else {
            escrow.settleForId(0);
            assertEq(testToken.balanceOf(seller), amount);

            // revert on retry
            vm.expectRevert(bytes("0 amount"));
            escrow.settleForId(0);
         }
         vm.stopPrank();
    }

    function testFuzz_SettleForAllIds(uint32 timePassed, uint256 amount) public {
        vm.assume(timePassed <= 4 days && amount > 0 && amount <= 10e18);
        uint256[] memory ids = new uint[](3);

        vm.startPrank(buyer);
        for (uint256 i; i < 3; ++i) {
            vm.expectEmit(true, false, false, true);
            emit NewDeposit(seller, i);
            escrow.enterEscrow(seller, testToken, amount * (i + 1));

            ids[i] = i;
        }
        vm.stopPrank();

        vm.warp(block.timestamp + timePassed);
        vm.prank(seller);
        escrow.settleForIds(ids);

        if (timePassed < 3 days) {
            assertEq(testToken.balanceOf(seller), 0);
        } else {
            assertEq(testToken.balanceOf(seller), 6 * amount);
        }
    }
}
