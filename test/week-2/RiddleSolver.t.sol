// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Test } from "forge-std/Test.sol";

import { RiddleSolver } from "../../src/week-2/RiddleSolver.sol";
import { Overmint1 } from "../../src//week-2/riddles/Overmint1.sol";
import { Overmint2 } from "../../src//week-2/riddles/Overmint2.sol";

contract RiddleSolverTest is Test {
    Overmint1 private overmint1;
    Overmint2 private overmint2;
    RiddleSolver private riddleSolver;
    address private owner = address(0x1234);

    function setUp() public {
        overmint1 = new Overmint1();
        overmint2 = new Overmint2();

        vm.prank(owner);
        riddleSolver = new RiddleSolver(overmint1, overmint2);
    }

    function test_exploitMint1() public {
        riddleSolver.exploitMint1();
        assertTrue(overmint1.success(owner));
    }

    function test_exploitMint2() public {
        riddleSolver.exploitMint2();
        vm.prank(owner);
        assertTrue(overmint2.success());
    }
}
