// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC777 } from "@openzeppelin/contracts/token/ERC777/ERC777.sol";

import { BojackToken, TokenSaleManager } from "../../src/week-1/BondingCurve.sol";
import { ERC1363 } from "./utils/ERC1363.sol";

contract TokenSaleManagerTest is Test {
    event Transfer(address indexed from, address indexed to, uint256 value);

    TokenSaleManager private manager;
    BojackToken private bojackToken;

    // setting up test token
    IERC20 private testToken = new ERC20("Test Token", "TT");
    ERC777 private token777 = new ERC777("Test Token777", "TT777", new address[](0));
    ERC1363 private token1363 = new ERC1363("Test Token1363", "TT1363");

    // setting up test users
    address private testUser = address(0x1234);
    address private anotherUser = address(0x1111);

    function setUp() public {
        manager = new TokenSaleManager();
        bojackToken = BojackToken(manager.getTokenAddress());
    }

    function test_CalculateAvgPrice() public {
        uint256 depositAmount = 500e18;

        uint256 quotePrice = manager.calculateAvgPrice(depositAmount);
        // average price should be 1.58 i.e. (0 + sqrt(500*2)) / 2
        assertEq(quotePrice / 1e16, 158);
    }

    function test_Buy_WhenInitialPriceIsZero() public {
        uint256 depositAmount = 500e18;

        deal(address(testToken), testUser, depositAmount);
        vm.startPrank(testUser);
        testToken.approve(address(manager), depositAmount);

        vm.expectEmit(true, true, false, true);
        // should emit ~158e16 amount
        emit Transfer(address(0), testUser, 316_227_766_016_837_933_100);
        manager.buy(depositAmount, address(testToken));

        vm.stopPrank();

        // check for BojackToken balance. minted amount should be depositAmount*2/sqrt(10)
        assertEq(bojackToken.balanceOf(testUser), 316_227_766_016_837_933_100);
        assertEq(bojackToken.totalSupply(), 316_227_766_016_837_933_100);
        // check current price of the BojackToken
        assertEq(manager.getCurrentPrice() / 1e15, 3162);
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
        assertEq(bojackToken.balanceOf(anotherUser), 1_132_909_908_602_105_924_200);
        assertEq(bojackToken.totalSupply(), prevSupply + 1_132_909_908_602_105_924_200);

        // check current price of the BojackToken
        assertEq(manager.getCurrentPrice() / 1e16, 1449);
    }

    function test_Buy_SmallAmounts() public whenInitialPriceIsNotZero {
        uint256 prevSupply = IERC20(bojackToken).totalSupply();

        deal(address(testToken), anotherUser, 10_000e18);
        vm.startPrank(anotherUser);
        testToken.approve(address(manager), 10_000e18);

        manager.buy(1e18, address(testToken));
        vm.stopPrank();

        // check for BojackToken balance.
        assertEq(bojackToken.balanceOf(anotherUser), 316_069_810_050_346_400);
        assertEq(bojackToken.totalSupply(), prevSupply + 316_069_810_050_346_400);

        // check current price of the BojackToken
        assertEq(manager.getCurrentPrice() / 1e15, 3165);
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
        assertEq(bojackToken.balanceOf(anotherUser), 1_132_909_908_602_105_924_200);
        assertEq(bojackToken.totalSupply(), prevSupply + 1_132_909_908_602_105_924_200);

        // check current price of the BojackToken
        assertEq(manager.getCurrentPrice() / 1e16, 1449);
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
        assertEq(bojackToken.balanceOf(anotherUser), 1_132_909_908_602_105_924_200);
        assertEq(bojackToken.totalSupply(), prevSupply + 1_132_909_908_602_105_924_200);

        // check current price of the BojackToken
        assertEq(manager.getCurrentPrice() / 1e16, 1449);
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
        assertEq(bojackToken.balanceOf(anotherUser), 1_132_909_908_602_105_924_200);
        assertEq(bojackToken.totalSupply(), prevSupply + 1_132_909_908_602_105_924_200);

        // check current price of the BojackToken
        assertEq(manager.getCurrentPrice() / 1e16, 1449);
    }

    function test_Sell() public whenInitialPriceIsNotZero {
        uint256 prevSupply = IERC20(bojackToken).totalSupply();
        uint256 prevTokenbalance = testToken.balanceOf(address(manager));

        vm.startPrank(testUser);
        manager.sell(100e18, address(testToken));

        uint256 expectedNewSupply = prevSupply - 100e18;

        vm.stopPrank();

        // check for erc20 balances
        assertEq(testToken.balanceOf(testUser), 266_227_766_016_837_933_100);
        assertEq(testToken.balanceOf(address(manager)), prevTokenbalance - 266_227_766_016_837_933_100);

        // check for BojackToken balance.
        assertEq(bojackToken.balanceOf(testUser), expectedNewSupply);
        assertEq(bojackToken.totalSupply(), expectedNewSupply);

        // check current price of the BojackToken
        assertEq(manager.getCurrentPrice() / 1e16, 216);
    }

    function test_Sell_RevertWhenRandomERC20() public whenInitialPriceIsNotZero {
        IERC20 randomToken = new ERC20("Random Token", "RT");

        vm.prank(testUser);
        vm.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
        manager.sell(100e18, address(randomToken));

        // check current price of the BojackToken. should be same as before
        assertEq(manager.getCurrentPrice() / 1e16, 316);
    }
}
