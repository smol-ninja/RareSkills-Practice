// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Test } from "forge-std/Test.sol";

import { MerkleDiscountNFT } from "../../src/week-2/MerkleDiscountNFT.sol";

abstract contract MerkleDiscountNftTest is Test {
    error MintingClosed();
    error NotEnoughEtherSent();
    error AlreadyMinted();
    error InvalidProof();

    MerkleDiscountNFT internal nft;

    // whitelisted address
    address internal userA = address(0x1001);
    address internal userB = address(0x1002);
    address internal userC = address(0x1003);
    address internal userD = address(0x1004);
    address internal userE = address(0x1005);

    // non-whitelisted address
    address internal notuserAddress = makeAddr("notuserAddress");

    address internal owner = makeAddr("owner");

    address[] private users = [userA, userB, userC, userD, userE, notuserAddress];

    function setUp() public virtual {
        for (uint256 i; i < users.length; ++i) {
            deal(users[i], 3 ether);
        }
        vm.prank(owner);
        nft = new MerkleDiscountNFT(0x7ac231947135471a6af7f1b944c422bac53b5eee7759b82171feadff411a423f);
    }

    function test_supportsInterface() public {
        assertTrue(nft.supportsInterface(0x2a55205a));
    }

    modifier SaleComplete() {
        for (uint256 i; i < 20; ++i) {
            vm.prank(users[i % 5]);
            nft.mint{ value: 0.1 ether }();
        }
        _;
    }

    function test_RoyaltyInfo() public {
        (address royaltyReceiver, uint256 royaltyAmount) = nft.royaltyInfo(1, 1 ether);
        assertEq(royaltyReceiver, owner);
        assertEq(royaltyAmount, 1 ether * 2.5 / 100);
    }

    function test_PublicMint() public {
        // success when ether sent is equal to the mint price
        vm.startPrank(notuserAddress);
        nft.mint{ value: 0.1 ether }();
        assertEq(nft.balanceOf(notuserAddress), 1);
        assertEq(address(nft).balance, 0.1 ether);

        // revert when ether sent is less than mint price
        vm.expectRevert(abi.encodeWithSelector(NotEnoughEtherSent.selector));
        nft.mint{ value: 0.09 ether }();

        // success when ether sent is more than mint price
        nft.mint{ value: 1 ether }();
        assertEq(nft.balanceOf(notuserAddress), 2);
        assertEq(notuserAddress.balance, 2.8 ether);
        assertEq(address(nft).balance, 0.2 ether);

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

        // revert if address is not whitelisted but valid proof
        vm.prank(notuserAddress);
        vm.expectRevert(abi.encodeWithSelector(InvalidProof.selector));
        nft.mintWhitelisted{ value: 0.1 ether }(3, proof);

        // revert if address is whitelisted but invalid proof
        vm.prank(userA);
        vm.expectRevert(abi.encodeWithSelector(InvalidProof.selector));
        nft.mintWhitelisted{ value: 0.1 ether }(3, proof);

        // revert if address is whitelisted and valid proof but invalid index
        vm.prank(userC);
        vm.expectRevert(abi.encodeWithSelector(InvalidProof.selector));
        nft.mintWhitelisted{ value: 0.1 ether }(1, proof);

        // success for whitelisted address and valid proof with valid index
        vm.prank(userC);
        nft.mintWhitelisted{ value: 0.1 ether }(3, proof);
        assertEq(nft.balanceOf(userC), 1);
        assertEq(address(nft).balance, 0.08 ether);
        assertEq(userC.balance, 2.92 ether);

        // fail for already minted
        vm.prank(userC);
        vm.expectRevert(abi.encodeWithSelector(AlreadyMinted.selector));
        nft.mintWhitelisted{ value: 1 ether }(3, proof);
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
    }
}
