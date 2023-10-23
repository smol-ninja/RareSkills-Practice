// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Test } from "forge-std/Test.sol";

import { GodMode } from "../../src/week-1/GodMode.sol";

contract GodModeTest is Test {
    error Unauthorized();

    GodMode private token;
    address private constant GOD_ADDRESS = address(0x1720);
    address private user = address(0x1234);

    function setUp() public {
        token = new GodMode(GOD_ADDRESS);
        deal(address(token), user, 100);
    }

    function test_RevertWhen_notGod() public {
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        token.transferByGod(user, address(0xDead), 100);
    }

    function test_TransferByGod() public {
        vm.prank(GOD_ADDRESS);
        token.transferByGod(user, address(0xDead), 100);

        assertEq(token.balanceOf(user), 0);
        assertEq(token.balanceOf(address(0xDead)), 100);
    }
}
