// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import { Test } from "forge-std/Test.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { Escrow } from "../../src/week-1/Escrow.sol";

contract EscrowTest is Test {
    event NewDeposit(address indexed recipient, uint256 id);

    Escrow private escrow;
    address private buyer = address(0x1234);
    address private seller = address(0x2345);
    ERC20 private testToken = new ERC20("Test Token", "TT");

    function setUp() public {
        escrow = new Escrow();
        deal(address(testToken), buyer, 10_000);
    }

    function test_EnterEscrow() public {
        vm.startPrank(buyer);
        testToken.approve(address(escrow), 1000);

        vm.expectEmit(true, false, false, true);
        emit NewDeposit(seller, 0);
        escrow.enterEscrow(seller, testToken, 1000);
        vm.stopPrank();

        assertEq(testToken.balanceOf(buyer), 9000);
        assertEq(testToken.balanceOf(address(escrow)), 1000);
    }

    modifier hasEscrow() {
        test_EnterEscrow();
        _;
    }

    function test_SettleForId_RevertWhenNotWaited() public hasEscrow {
        vm.prank(seller);
        vm.expectRevert(bytes("cant withdraw"));
        escrow.settleForId(0);
    }

    modifier givenThreeDays() {
        vm.warp(block.timestamp + 3 days);
        _;
    }

    function test_SettleForId() public hasEscrow givenThreeDays {
        vm.prank(seller);
        escrow.settleForId(0);

        assertEq(testToken.balanceOf(seller), 1000);
        assertEq(testToken.balanceOf(buyer), 9000);
    }

    function test_SettleForAllIds() public {
        vm.startPrank(buyer);
        testToken.approve(address(escrow), 10_000);

        vm.expectEmit(true, false, false, true);
        emit NewDeposit(seller, 0);
        escrow.enterEscrow(seller, testToken, 1000);

        vm.expectEmit(true, false, false, true);
        emit NewDeposit(seller, 1);
        escrow.enterEscrow(seller, testToken, 2000);

        vm.expectEmit(true, false, false, true);
        emit NewDeposit(seller, 2);
        escrow.enterEscrow(seller, testToken, 3000);
        vm.stopPrank();

        vm.warp(block.timestamp + 3 days);
        vm.prank(seller);
        escrow.settleForAllIds();

        assertEq(testToken.balanceOf(seller), 6000);
        assertEq(testToken.balanceOf(buyer), 4000);
    }
}
