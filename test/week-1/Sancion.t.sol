// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Test } from "forge-std/Test.sol";

import { Sanction } from "../../src/week-1/Sanction.sol";

contract SanctionTest is Test {
    Sanction private token;
    address private testUser;

    error AddressIsSanctioned(address);

    event SanctionStatus(address indexed, bool);

    function setUp() public {
        token = new Sanction();
        testUser = address(0x420);
        deal(address(token), testUser, 100);
    }

    function test_RevertWhen_NotOwner() public {
        vm.prank(address(0x1720));

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        token.addSanction(testUser);
    }

    function test_AddSanction() public {
        vm.expectEmit(true, false, false, true);
        emit SanctionStatus(testUser, true);
        token.addSanction(testUser);
        assertEq(token.hasSanction(testUser), true);
    }

    modifier whenAlreadySanctioned() {
        token.addSanction(testUser);
        _;
    }

    function test_RemoveSanction() public whenAlreadySanctioned {
        vm.expectEmit(true, false, false, true);
        emit SanctionStatus(testUser, false);
        token.removeSanction(testUser);
        assertEq(token.hasSanction(testUser), false);
    }

    function test_Transfer() public {
        vm.prank(testUser);

        token.transfer(address(0xa), 100);
        assertEq(token.balanceOf(testUser), 0);
    }

    function test_RevertTransfer() public whenAlreadySanctioned {
        vm.prank(testUser);

        vm.expectRevert(abi.encodeWithSelector(AddressIsSanctioned.selector, testUser));
        token.transfer(address(0xa), 100);
        assertEq(token.balanceOf(testUser), 100);
    }

    function test_RevertTransfer_SanctionedRecipient() public whenAlreadySanctioned {
        address newUser = address(0x1720);
        deal(address(token), newUser, 1000);

        vm.prank(newUser);

        vm.expectRevert(abi.encodeWithSelector(AddressIsSanctioned.selector, testUser));
        token.transfer(testUser, 100);
        assertEq(token.balanceOf(newUser), 1000);
    }
}
