// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Test } from "forge-std/Test.sol";
import { IERC2981 } from "@openzeppelin/contracts/interfaces/IERC2981.sol";

import { MerkleDiscountNFT } from "../../src/week-2/MerkleDiscountNFT.sol";

abstract contract MerkleDiscountNftTest is Test {
    event Minted(address indexed, uint256 indexed);

    error MintingClosed();
    error IncorrectEtherSent();
    error AlreadyMinted();
    error InvalidProof();
    error FailedToTransferEther();

    MerkleDiscountNFT internal nft;

    // whitelisted address
    address internal userA = address(0x1001);
    address internal userB = address(0x1002);
    address internal userC = address(0x1003);
    address internal userD = address(0x1004);
    address internal userE = address(0x1005);

    // non-whitelisted address
    address internal notWhitelisted = makeAddr("notWhitelisted");

    address internal owner = makeAddr("owner");

    address[6] private users = [userA, userB, userC, userD, userE, notWhitelisted];

    function setUp() public virtual {
        for (uint256 i; i < users.length; ++i) {
            deal(users[i], 3 ether);
        }
        vm.prank(owner);
        nft = new MerkleDiscountNFT(0x7ac231947135471a6af7f1b944c422bac53b5eee7759b82171feadff411a423f);
    }

    function test_supportsInterface(bytes4 interfaceId) public {
        if (interfaceId == type(IERC2981).interfaceId) {
            assertTrue(nft.supportsInterface(interfaceId));
        } else {
            assertFalse(nft.supportsInterface(interfaceId));
        }
    }

    modifier SaleComplete() {
        for (uint256 i; i < 20; ++i) {
            vm.prank(users[i % 5]);
            nft.mint{ value: 0.1 ether }();
        }
        _;
    }

    function test_RoyaltyInfo(uint256 price) public {
        vm.assume(price < type(uint112).max);
        (address royaltyReceiver, uint256 royaltyAmount) = nft.royaltyInfo(1, price);
        assertEq(royaltyReceiver, owner);
        assertEq(royaltyAmount, price * 25 / 1000);
    }

    function test_PublicMint() public {
        // success when ether sent is equal to the mint price
        vm.startPrank(notWhitelisted);

        vm.expectEmit(true, true, false, false);
        emit Minted(notWhitelisted, 1);
        nft.mint{ value: 0.1 ether }();
        assertEq(nft.balanceOf(notWhitelisted), 1);
        assertEq(address(nft).balance, 0.1 ether);

        // revert when ether sent is less than mint price
        vm.expectRevert(abi.encodeWithSelector(IncorrectEtherSent.selector));
        nft.mint{ value: 0.09 ether }();

        // success when ether sent is more than mint price
        vm.expectRevert(abi.encodeWithSelector(IncorrectEtherSent.selector));
        nft.mint{ value: 2.8 ether }();

        vm.stopPrank();
    }

    function test_TotalSupply_RevertOverMint() public SaleComplete {
        vm.prank(userA);
        vm.expectRevert(abi.encodeWithSelector(MintingClosed.selector));
        nft.mint{ value: 0.1 ether }();

        assertEq(nft.balanceOf(userA), 4);
        assertEq(address(nft).balance, 2 ether);
    }

    function test_WhitelistedMint() public {
        // proof corresponding to userC and index 3
        bytes32[] memory proof = new bytes32[](3);

        proof[0] = 0x1df37ecc76ddacb47d721470b4ffa1f5e86efd1856b54aeda6266e14804b3f47;
        proof[1] = 0xfb87a8546b051e852ad01fb1acc823d4066ae61881e2bb9ec7230d5070dba278;
        proof[2] = 0x77ceaa9a6b391c16a2ef5ff8d0586361c6aaad37062e9af77f9efdec30d06b8f;

        // revert when ether sent is less than mint price
        vm.prank(userC);
        vm.expectRevert(abi.encodeWithSelector(IncorrectEtherSent.selector));
        nft.mintWhitelisted{ value: 0.07 ether }(3, proof);

        // success when ether sent is more than mint price
        vm.prank(userC);
        vm.expectRevert(abi.encodeWithSelector(IncorrectEtherSent.selector));
        nft.mintWhitelisted{ value: 2.8 ether }(3, proof);

        // revert if address is not whitelisted but valid proof
        vm.prank(notWhitelisted);
        vm.expectRevert(abi.encodeWithSelector(InvalidProof.selector));
        nft.mintWhitelisted{ value: 0.08 ether }(3, proof);

        // revert if address is whitelisted but invalid proof
        vm.prank(userA);
        vm.expectRevert(abi.encodeWithSelector(InvalidProof.selector));
        nft.mintWhitelisted{ value: 0.08 ether }(3, proof);

        // revert if address is whitelisted and valid proof but invalid index
        vm.prank(userC);
        vm.expectRevert(abi.encodeWithSelector(InvalidProof.selector));
        nft.mintWhitelisted{ value: 0.08 ether }(1, proof);

        // success for whitelisted address and valid proof with valid index
        vm.prank(userC);
        vm.expectEmit(true, true, false, false);
        emit Minted(userC, 1);
        nft.mintWhitelisted{ value: 0.08 ether }(3, proof);
        assertEq(nft.balanceOf(userC), 1);
        assertEq(address(nft).balance, 0.08 ether);
        assertEq(userC.balance, 2.92 ether);

        // fail for already minted
        vm.prank(userC);
        vm.expectRevert(abi.encodeWithSelector(AlreadyMinted.selector));
        nft.mintWhitelisted{ value: 0.08 ether }(3, proof);

        // revert when supply cap has reached
        uint256 remainingSupply = nft.MAX_SUPPLY() - nft.totalSupply();
        for (uint256 i; i < remainingSupply; ++i) {
            vm.prank(userC);
            nft.mint{ value: 0.1 ether }();
        }
        vm.prank(userA);
        proof = new bytes32[](2);
        proof[0] = 0xc4a4487caaaaa1fd5f6a29a75cb3cad10e405d17052c36a1a12dbf1beb67d2b5;
        proof[1] = 0x77ceaa9a6b391c16a2ef5ff8d0586361c6aaad37062e9af77f9efdec30d06b8f;
        vm.expectRevert(abi.encodeWithSelector(MintingClosed.selector));
        nft.mintWhitelisted{ value: 0.08 ether }(1, proof);
    }

    function test_WithdrawSaleFund() public SaleComplete {
        // revert if unknown address withdraws
        vm.prank(userA);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        nft.withdrawFunds();

        // success if owner withdraws
        vm.prank(owner);
        nft.withdrawFunds();
        assertEq(address(nft).balance, 0);
        assertEq(owner.balance, 2 ether);

        // fail if owner is a contract and doesn't implement payable or fallback
        vm.etch(owner,  hex'01');
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(FailedToTransferEther.selector));
        nft.withdrawFunds();
    }
}
