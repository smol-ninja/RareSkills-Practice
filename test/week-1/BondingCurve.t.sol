// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC777 } from "@openzeppelin/contracts/token/ERC777/ERC777.sol";

import { BojackToken, TokenSaleManager } from "../../src/week-1/BondingCurve.sol";
import { ERC1363 } from "./utils/ERC1363.sol";

contract ERC1363Token is ERC1363 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) { }
}

contract TokenSaleManagerTest is Test {
    event Transfer(address indexed from, address indexed to, uint256 value);

    TokenSaleManager private manager;
    BojackToken private bojackToken;

    // setting up test token
    IERC20 private testToken = new ERC20("Test Token", "TT");
    ERC777 private token777 = new ERC777("Test Token777", "TT777", new address[](0));
    ERC1363Token private token1363 = new ERC1363Token("Test Token1363", "TT1363");

    // setting up test users
    address private testUser = address(0x1234);
    address private anotherUser = address(0x1111);

    function setUp() public {
        manager = new TokenSaleManager();
        bojackToken = BojackToken(manager.getTokenAddress());
    }

    function test_CalculateAvgPrice() public {
        uint256 depositAmount = 500e18;

        uint256 quotePrice = manager.calculateAvgPrice(depositAmount, address(testToken));
        // average price should be 1.58 i.e. (0 + sqrt(10)) / 2
        assertEq(quotePrice, 1);
    }

    function test_Buy_WhenInitialPriceIsZero() public {
        uint256 depositAmount = 500e18;

        deal(address(testToken), testUser, depositAmount);
        vm.startPrank(testUser);
        testToken.approve(address(manager), depositAmount);

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), testUser, 300e18);
        manager.buy(depositAmount, address(testToken));

        vm.stopPrank();

        // check for BojackToken balance. minted amount should be depositAmount*2/sqrt(10)
        assertEq(bojackToken.balanceOf(testUser), 300e18);
        assertEq(bojackToken.totalSupply(), 300e18);
        // check current price of the BojackToken
        assertEq(manager.getCurrentPrice(), 3);
    }

    modifier whenInitialPriceIsNotZero() {
        test_Buy_WhenInitialPriceIsZero();
        _;
    }

    function test_Buy() public whenInitialPriceIsNotZero {
        uint256 prevSupply = IERC20(bojackToken).totalSupply();

        deal(address(testToken), anotherUser, 10_000e18);
        vm.startPrank(anotherUser);
        testToken.approve(address(manager), 10_000e18);

        manager.buy(10_000e18, address(testToken));
        vm.stopPrank();

        // check for BojackToken balance.
        assertEq(bojackToken.balanceOf(anotherUser), 1100e18);
        assertEq(bojackToken.totalSupply(), prevSupply + 1100e18);

        // check current price of the BojackToken
        assertEq(manager.getCurrentPrice(), 14);
    }

    function test_ERC777_Implementation() public whenInitialPriceIsNotZero {
        uint256 prevSupply = IERC20(bojackToken).totalSupply();

        deal(address(token777), anotherUser, 10_000e18);

        vm.startPrank(anotherUser);
        token777.send(address(manager), 10_000e18, "");
        vm.stopPrank();

        // check for token777 balances
        assertEq(token777.balanceOf(anotherUser), 0);
        assertEq(token777.balanceOf(address(manager)), 10_000e18);

        // check for BojackToken balance.
        assertEq(bojackToken.balanceOf(anotherUser), 1100e18);
        assertEq(bojackToken.totalSupply(), prevSupply + 1100e18);

        // check current price of the BojackToken
        assertEq(manager.getCurrentPrice(), 14);
    }

    function test_ERC1363_TransferReceived() public whenInitialPriceIsNotZero {
        uint256 prevSupply = IERC20(bojackToken).totalSupply();

        deal(address(token1363), anotherUser, 10_000e18);

        vm.startPrank(anotherUser);
        token1363.transferAndCall(address(manager), 10_000e18, "");
        vm.stopPrank();

        // check for token1363 balances
        assertEq(token1363.balanceOf(anotherUser), 0);
        assertEq(token1363.balanceOf(address(manager)), 10_000e18);

        // check for BojackToken balance.
        assertEq(bojackToken.balanceOf(anotherUser), 1100e18);
        assertEq(bojackToken.totalSupply(), prevSupply + 1100e18);

        // check current price of the BojackToken
        assertEq(manager.getCurrentPrice(), 14);
    }

    function test_ERC1363_ApprovalReceived() public whenInitialPriceIsNotZero {
        uint256 prevSupply = IERC20(bojackToken).totalSupply();

        deal(address(token1363), anotherUser, 10_000e18);

        vm.startPrank(anotherUser);
        token1363.approveAndCall(address(manager), 10_000e18, "");
        vm.stopPrank();

        // check for token1363 balances
        assertEq(token1363.balanceOf(anotherUser), 0);
        assertEq(token1363.balanceOf(address(manager)), 10_000e18);

        // check for BojackToken balance.
        assertEq(bojackToken.balanceOf(anotherUser), 1100e18);
        assertEq(bojackToken.totalSupply(), prevSupply + 1100e18);

        // check current price of the BojackToken
        assertEq(manager.getCurrentPrice(), 14);
    }

    function test_sell() public whenInitialPriceIsNotZero {
        uint256 prevSupply = IERC20(bojackToken).totalSupply();

        vm.startPrank(testUser);
        manager.sell(100e18, address(testToken));

        vm.stopPrank();

        // check for erc20 balances
        assertEq(testToken.balanceOf(testUser), 250e18);
        assertEq(testToken.balanceOf(address(manager)), 250e18);

        // check for BojackToken balance.
        assertEq(bojackToken.balanceOf(testUser), 200e18);
        assertEq(bojackToken.totalSupply(), prevSupply - 100e18);

        // check current price of the BojackToken
        assertEq(manager.getCurrentPrice(), 2);
    }
}
