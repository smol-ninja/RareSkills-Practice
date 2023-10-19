// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Test } from "forge-std/Test.sol";

import { UD60x18, ud } from "@prb/math/UD60x18.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC3156FlashBorrower } from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";

import { Pair } from "../../src/week-3-5-amm/Pair.sol";
import { Factory } from "../../src/week-3-5-amm/Factory.sol";

import { FlashLoanBorrower, NonImplementedBorrower } from "./FlashLoanBorrower.sol";

contract PairTest is Test {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Sync(uint112 reserve0, uint112 reserve1);

    error UnsupportedToken();
    error FlashLoanFailed();
    error Overflow();
    error MinimumLiquidity();
    error InsufficientLiquidity();
    error ZeroOutput();
    error InsufficientReserve();
    error ZeroInput();
    error XYK();

    Pair private pair;
    Factory private factory = new Factory();
    ERC20 private token0 = new ERC20("token0", "t0");
    ERC20 private token1 = new ERC20("token1", "t1");
    address private alice = makeAddr("alice");
    address private user = makeAddr("user");

    function setUp() public {
        vm.assume(address(token0) < address(token1));
        address pairAdd = factory.createPair(address(token0), address(token1));
        pair = Pair(pairAdd);

        vm.startPrank(alice);
        token0.approve(address(pair), type(uint256).max);
        token1.approve(address(pair), type(uint256).max);
        vm.stopPrank();
        vm.startPrank(user);
        token0.approve(address(pair), type(uint256).max);
        token1.approve(address(pair), type(uint256).max);
        vm.stopPrank();
    }

    function test_InitialStates() public {
        assertEq(pair.factory(), address(factory));
        assertEq(pair.MINIMUM_LIQUIDITY(), 1000);
        assertEq(pair.token0(), address(token0));
        assertEq(pair.token1(), address(token1));
    }

    function testFuzz_Mint_WhenNotInitiated(uint256 deposit0, uint256 deposit1) public {
        vm.assume(deposit0 < type(uint112).max && deposit1 < type(uint112).max);

        deal(address(token0), alice, deposit0);
        deal(address(token1), alice, deposit1);

        vm.startPrank(alice);
        token0.transfer(address(pair), deposit0);
        token1.transfer(address(pair), deposit1);
        vm.stopPrank();

        uint256 expectedTotalSupply = Math.sqrt(deposit0 * deposit1);

        if (expectedTotalSupply <= pair.MINIMUM_LIQUIDITY()) {
            // case when minted liquidity does not mean MINIMUM_LIQUIDITY
            vm.expectRevert(abi.encodeWithSelector(MinimumLiquidity.selector));
            pair.mint(alice);
        } else {
            // expected Emits
            vm.expectEmit();
            emit Transfer(address(0), address(1), 1000);
            vm.expectEmit();
            emit Transfer(address(0), alice, expectedTotalSupply - 1000);
            vm.expectEmit();
            emit Mint(alice, uint112(deposit0), uint112(deposit1));
            vm.expectEmit();
            emit Sync(uint112(deposit0), uint112(deposit1));

            uint256 liquidity = pair.mint(alice);

            // assertion checks
            assertEq(liquidity, expectedTotalSupply - 1000);
            assertEq(pair.totalSupply(), expectedTotalSupply);

            // check reserves
            (uint256 r0, uint256 r1, uint32 bt) = pair.getReserves();
            assertEq(r0, uint112(deposit0));
            assertEq(r1, uint112(deposit1));
            assertTrue(bt > 0);
            assertEq(pair.kLast(), r0 * r1);
            assertEq(token0.balanceOf(address(pair)), r0);
            assertEq(token1.balanceOf(address(pair)), r1);
        }
    }

    modifier GivenPoolInitiated() {
        deal(address(token0), alice, 33_000_000e18);
        deal(address(token1), alice, 21_000e18);
        vm.startPrank(alice);
        token0.transfer(address(pair), 33_000_000e18);
        token1.transfer(address(pair), 21_000e18);
        pair.mint(alice);
        // liquidity = 832,466.2155306965
        // price = 1571.4285714286
        vm.stopPrank();

        deal(address(token0), user, 20_000e18);
        deal(address(token1), user, 10e18);
        _;
    }

    function testRevert_Mint_Overflow() public GivenPoolInitiated {
        deal(address(token0), user, 2**113);

        vm.prank(user);
        token0.transfer(address(pair), type(uint112).max);
        // failure due to Overflow
        vm.expectRevert(abi.encodeWithSelector(Overflow.selector));
        pair.mint(user);
    }

    function testRevert_Mint_ZeroLiquidity() public GivenPoolInitiated {
        vm.prank(user);
        token0.transfer(address(pair), 1);
        // failure due to minted token equals 0
        vm.expectRevert(abi.encodeWithSelector(InsufficientLiquidity.selector));
        pair.mint(user);
    }

    function test_Mint() public GivenPoolInitiated {
        (uint256 r00, uint256 r10,) = pair.getReserves();
        uint256 supply0 = pair.totalSupply();

        vm.startPrank(user);
        // success
        token0.transfer(address(pair), 10_000e18);
        token1.transfer(address(pair), 7e18);
        vm.stopPrank();

        uint256 liquidity = pair.mint(user);

        (uint256 r01, uint256 r11,) = pair.getReserves();
        uint256 supply1 = pair.totalSupply();

        // assertion checks
        assertEq(liquidity / 1e16, 25_226);
        assertEq((r01 - r00) / 1e18, 10_000);
        assertEq((r11 - r10) / 1e10, 636_363_636);
        assertEq((supply1 - supply0), liquidity);
        assertGe(token0.balanceOf(address(pair)), r01);
        assertGe(token1.balanceOf(address(pair)), r11);
        assertEq(pair.kLast(), r01 * r11);

        (r00, r10, supply0) = (r01, r11, supply1);

        vm.startPrank(user);
        token0.transfer(address(pair), 10_000e18);
        token1.transfer(address(pair), 1e18);
        vm.stopPrank();

        liquidity = pair.mint(user);

        (r01, r11,) = pair.getReserves();
        supply1 = pair.totalSupply();

        // assertion checks
        assertEq(liquidity / 1e16, 6486);
        assertEq((r01 - r00) / 1e18, 2571);
        assertEq((r11 - r10) / 1e10, 163_636_363);
        assertEq((supply1 - supply0), liquidity);
        assertGe(token0.balanceOf(address(pair)), r01);
        assertGe(token1.balanceOf(address(pair)), r11);
        assertEq(pair.kLast(), r01 * r11);
    }

    function test_Mint_WhenSmallDeposits() public GivenPoolInitiated {
        (uint256 r00, uint256 r10,) = pair.getReserves();

        uint256 supply0 = pair.totalSupply();

        vm.startPrank(user);
        token0.transfer(address(pair), 1e18);
        token1.transfer(address(pair), 7e15); // 0.0006363636364
        vm.stopPrank();

        uint256 liquidity = pair.mint(user);

        (uint256 r01, uint256 r11,) = pair.getReserves();
        uint256 supply1 = pair.totalSupply();

        // assertion checks
        assertEq(liquidity / 1e12, 25_226); // 0.025_22624895
        assertEq((r01 - r00), 1e18);
        assertEq((r11 - r10) / 1e6, 636_363_636);
        assertEq((supply1 - supply0), liquidity);
        assertGe(token0.balanceOf(address(pair)), r01);
        assertGe(token1.balanceOf(address(pair)), r11);
        assertEq(pair.kLast(), r01 * r11);
    }

    modifier GivenUserAddedLiquidity() {
        vm.startPrank(user);
        token0.transfer(address(pair), 10_000e18);
        token1.transfer(address(pair), 7e18);

        pair.mint(user);
        vm.stopPrank();
        _;
    }

    function testFuzz_Burn(uint256 burnQuantity) public GivenPoolInitiated GivenUserAddedLiquidity {
        vm.assume(burnQuantity <= pair.balanceOf(user));

        vm.prank(user);
        pair.transfer(address(pair), burnQuantity);

        (uint256 r00, uint256 r10,) = pair.getReserves();
        uint256 totalSupply0 = pair.totalSupply();
        uint256 userBalance0 = token0.balanceOf(user);
        uint256 userBalance1 = token1.balanceOf(user);

        (uint256 amount0, uint256 amount1) = pair.burn(user);
        (uint256 r01, uint256 r11,) = pair.getReserves();
        uint256 totalSupply1 = pair.totalSupply();

        // assert checks
        assertEq(totalSupply0 - totalSupply1, burnQuantity);
        assertEq(r00 - r01, r00 * burnQuantity / totalSupply0);
        assertEq(r10 - r11, r10 * burnQuantity / totalSupply0);
        assertEq(amount0, r00 - r01);
        assertEq(amount1, r10 - r11);
        assertGe(token0.balanceOf(address(pair)), r01);
        assertGe(token1.balanceOf(address(pair)), r11);
        assertEq(token0.balanceOf(user), userBalance0 + amount0);
        assertEq(token1.balanceOf(user), userBalance1 + amount1);
        assertEq(pair.kLast(), r01 * r11);
    }

    function test_BurnAll() public GivenPoolInitiated {
        uint256 aliceLiquidity = pair.balanceOf(alice);
        uint256 totalSupply = pair.totalSupply();
        vm.prank(alice);
        pair.transfer(address(pair), aliceLiquidity);

        (uint256 amount0, uint256 amount1) = pair.burn(user);

        assertEq(pair.totalSupply(), 1000);
        assertEq(amount0, (33_000_000e18 * aliceLiquidity) / totalSupply);
        assertEq(amount1, (21_000e18 * aliceLiquidity) / totalSupply);
    }

    function testFuzz_Skim(uint256 amount0, uint256 amount1) public {
        vm.assume(amount0 > type(uint112).max && amount1 > type(uint112).max);
        deal(address(token0), user, amount0);
        deal(address(token1), user, amount1);

        vm.startPrank(user);
        token0.transfer(address(pair), amount0);
        token1.transfer(address(pair), amount1);
        vm.stopPrank();

        (uint256 r0, uint256 r1,) = pair.getReserves();

        vm.expectEmit();
        emit Transfer(address(pair), user, amount0 - r0);
        vm.expectEmit();
        emit Transfer(address(pair), user, amount1 - r1);
        pair.skim(user);
    }

    function testFuzz_Sync(uint256 amount0, uint256 amount1) public GivenPoolInitiated {
        vm.assume(amount0 > 0 && amount1 > 0);
        deal(address(token0), user, amount0);
        deal(address(token1), user, amount1);

        vm.startPrank(user);
        token0.transfer(address(pair), amount0);
        token1.transfer(address(pair), amount1);
        vm.stopPrank();

        if (
            token0.balanceOf(address(pair)) >= type(uint112).max || token1.balanceOf(address(pair)) >= type(uint112).max
        ) {
            vm.expectRevert(abi.encodeWithSelector(Overflow.selector));
        } else {
            vm.expectEmit();
            emit Sync(uint112(token0.balanceOf(address(pair))), uint112(token1.balanceOf(address(pair))));
        }
        pair.sync();
    }

    function testRevert_Swap() public GivenPoolInitiated {
        vm.expectRevert(abi.encodeWithSelector(ZeroOutput.selector));
        pair.swap(0, 0, user, "");

        (uint112 r0, uint112 r1,) = pair.getReserves();
        vm.expectRevert(abi.encodeWithSelector(InsufficientReserve.selector));
        pair.swap(r0 + 1, 0, user, "");
        vm.expectRevert(abi.encodeWithSelector(InsufficientReserve.selector));
        pair.swap(0, r1 + 1, user, "");

        vm.expectRevert(abi.encodeWithSelector(ZeroInput.selector));
        pair.swap(0, 1, user, "");

        deal(address(token0), user, type(uint112).max); 
        vm.prank(user);
        token0.transfer(address(pair), type(uint112).max);
        vm.expectRevert(abi.encodeWithSelector(Overflow.selector));
        pair.swap(0, 1, user, "");
    }

    function test_Swap1() public GivenPoolInitiated {
        uint256 userBalance00 = token0.balanceOf(user);
        uint256 userBalance10 = token1.balanceOf(user);

        vm.prank(user);
        token0.transfer(address(pair), 3_143_156_491e12);

        skip(10 days);
        pair.swap(0, 2e18, user, "");

        uint256 userBalance01 = token0.balanceOf(user);
        uint256 userBalance11 = token1.balanceOf(user);

        // assertions
        assertEq((userBalance00 - userBalance01) / 1e12, 3_143_156_491);
        assertEq((userBalance11 - userBalance10) / 1e15, 1994);

        // failure with XYK error
        vm.prank(user);
        token0.transfer(address(pair), 100);
        vm.expectRevert(abi.encodeWithSelector(XYK.selector));
        pair.swap(0, 2e18, user, "");
    }

    function test_Swap2() public GivenPoolInitiated {
        uint256 userBalance00 = token0.balanceOf(user);
        uint256 userBalance10 = token1.balanceOf(user);

        vm.prank(user);
        token1.transfer(address(pair), 2e18);

        pair.swap(3000e18, 0, user, "");

        uint256 userBalance01 = token0.balanceOf(user);
        uint256 userBalance11 = token1.balanceOf(user);

        // assertions
        assertEq((userBalance01 - userBalance00) / 1e18, 2991);
        assertEq((userBalance10 - userBalance11), 2e18);
    }

    function testFuzz_Flashloan(uint112 amount) public GivenPoolInitiated {
        (uint112 ri0, uint112 ri1,) = pair.getReserves();

        IERC3156FlashBorrower borrower = new FlashLoanBorrower();
        uint256 expectedFee = (uint256(amount) * 30) / 10_000;
        deal(address(token0), address(borrower), expectedFee);
        deal(address(token1), address(borrower), expectedFee);

        bool expectedStatus = true;
        vm.startPrank(user);
        if (amount > ri0) {
            vm.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
            expectedStatus = false;
            expectedFee = 0;
        }
        bool status = pair.flashLoan(borrower, address(token0), amount, "");
        (uint112 rn0, uint112 rn1,) = pair.getReserves();

        // assertion
        assertEq(status, expectedStatus);
        assertEq(rn1, ri1);
        assertEq(rn0, ri0 + expectedFee);

        vm.assume(amount < ri1);
        status = pair.flashLoan(borrower, address(token1), amount, "");
        (ri0, ri1) = (rn0, rn1);
        (rn0, rn1,) = pair.getReserves();

        // assertion
        assertEq(status, expectedStatus);
        assertEq(rn0, ri0);
        assertEq(rn1, ri1 + expectedFee);

        // failure
        IERC3156FlashBorrower nonImplementedBorrower = new NonImplementedBorrower();
        vm.expectRevert(abi.encodeWithSelector(FlashLoanFailed.selector));
        pair.flashLoan(nonImplementedBorrower, address(token0), amount, "");

        // failure
        vm.expectRevert(abi.encodeWithSelector(UnsupportedToken.selector));
        pair.flashLoan(borrower, address(1234), amount, "");

        vm.stopPrank();
    }

    function testFuzz_Twap(uint256 amount1) public GivenPoolInitiated {
        uint256 lastCumPrice0 = pair.price0CumulativeLast();
        uint256 lastCumPrice1 = pair.price1CumulativeLast();
        (, uint112 ri1,) = pair.getReserves();

        vm.assume(amount1 > 0 && amount1 < ri1);
        uint256 amount0 = amount1 * 1_000_000;
        deal(address(token0), alice, amount0);

        vm.prank(alice);
        token0.transfer(address(pair), amount0);

        skip(7 days);
        pair.swap(0, amount1, user, "");
        uint256 cumPrice0 = pair.price0CumulativeLast();
        uint256 cumPrice1 = pair.price1CumulativeLast();
        (uint112 rn0, uint112 rn1,) = pair.getReserves();
        uint256 price1 = UD60x18.unwrap(ud(rn0).div(ud(rn1)));
        uint256 price0 = UD60x18.unwrap(ud(rn1).div(ud(rn0)));

        // assertions
        assertEq(cumPrice1 - lastCumPrice1, price1 * 7 days);
        assertEq(cumPrice0 - lastCumPrice0, price0 * 7 days);
        assertTrue(cumPrice1 > lastCumPrice1);
        assertTrue(cumPrice0 > lastCumPrice0);
    }

    function test_MaxFlashLoan() public GivenPoolInitiated {
        (uint112 r0, uint112 r1,) = pair.getReserves();

        // failure
        vm.expectRevert(abi.encodeWithSelector(UnsupportedToken.selector));
        pair.maxFlashLoan(address(1234));

        // success
        uint256 amount = pair.maxFlashLoan(address(token0));
        assertEq(amount, r0);

        // success
        amount = pair.maxFlashLoan(address(token1));
        assertEq(amount, r1);
    }

    function testFuzz_FlashFee(uint256 amount) public {
        vm.assume(amount < type(uint112).max);
        // failure
        vm.expectRevert(abi.encodeWithSelector(UnsupportedToken.selector));
        pair.flashFee(address(1234), amount);

        // success
        uint256 fee = pair.flashFee(address(token0), amount);
        assertEq(fee, (amount * 30) / 10_000);

        // success
        fee = pair.flashFee(address(token1), amount);
        assertEq(fee, (amount * 30) / 10_000);
    }
}
