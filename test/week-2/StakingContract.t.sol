// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { StakingContract, RewardToken } from "../../src/week-2/StakingContract.sol";
import { MerkleDiscountNFT } from "../../src/week-2/MerkleDiscountNFT.sol";
import { MerkleDiscountNftTest } from "./MerkleDiscountNFT.t.sol";

contract StakingContractTest is MerkleDiscountNftTest {
    StakingContract private stakingContract;
    uint256[7] private randomIds = [2, 4, 6, 7, 8, 16, 18];
    address[7] private ownersOfIds = [userB, userD, userA, userB, userC, userA, userC];

    event Stake(address indexed, uint256 indexed);
    event Unstake(address indexed, uint256 indexed);
    event Claim(address indexed, uint256 indexed, uint256);

    error NoTokenRecordFound();
    error UnknownNFTFound();
    error Unauthorized();

    function setUp() public override {
        super.setUp();
        stakingContract = new StakingContract(nft);
    }

    function test_ReverWhen_UnathorizedMint() public {
        RewardToken rewardToken = stakingContract.rewardToken();
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        rewardToken.mint(address(this), 1);
    }

    function test_Stake() public SaleComplete {
        vm.startPrank(userA);
        nft.setApprovalForAll(address(stakingContract), true);

        // revert for random tokenId
        vm.expectRevert(bytes("ERC721: caller is not token owner or approved"));
        stakingContract.stake(2);

        // stake for valid tokenid
        vm.expectEmit(true, true, false, false);
        emit Stake(userA, 6);
        stakingContract.stake(6);

        assertEq(nft.ownerOf(6), address(stakingContract));

        // stake with direct nft transfer
        nft.safeTransferFrom(userA, address(stakingContract), 16);
        assertEq(nft.ownerOf(16), address(stakingContract));

        vm.stopPrank();
    }

    function test_Stake_RevertForRandomNFT() public {
        vm.startPrank(userA);

        // stake a random NFT
        MerkleDiscountNFT randomNFT = new MerkleDiscountNFT(0x0);
        randomNFT.mint{ value: 0.1 ether }();
        randomNFT.setApprovalForAll(address(stakingContract), true);
        vm.expectRevert(abi.encodeWithSelector(UnknownNFTFound.selector));
        randomNFT.safeTransferFrom(userA, address(stakingContract), 1);

        skip(12 hours);

        vm.expectRevert(abi.encodeWithSelector(NoTokenRecordFound.selector));
        stakingContract.claimRewards(1);

        vm.stopPrank();
    }

    modifier RandomizeStake() {
        for (uint256 i; i < randomIds.length; ++i) {
            vm.startPrank(ownersOfIds[i]);
            nft.approve(address(stakingContract), randomIds[i]);
            vm.expectEmit(true, true, false, false);
            emit Stake(ownersOfIds[i], randomIds[i]);
            stakingContract.stake(randomIds[i]);

            vm.stopPrank();
        }
        _;
    }

    function test_ClaimRewards() public SaleComplete RandomizeStake {
        skip(12 hours);

        vm.startPrank(userC); // 8 and 18

        // revert for random token id
        vm.expectRevert(abi.encodeWithSelector(NoTokenRecordFound.selector));
        stakingContract.claimRewards(2);

        // success case
        vm.expectEmit(true, true, false, true);
        emit Claim(userC, 8, 5e18);
        stakingContract.claimRewards(8);
        assertEq(stakingContract.rewardToken().balanceOf(userC), 5e18);

        skip(1 minutes);
        // success case
        vm.expectEmit(true, true, false, true);
        emit Claim(userC, 8, 6_944_444_444_444_444);
        stakingContract.claimRewards(8);
        assertEq(stakingContract.rewardToken().balanceOf(userC), 5e18 + 6_944_444_444_444_444);

        vm.stopPrank();
    }

    function test_Unstake() public SaleComplete RandomizeStake {
        assertEq(nft.ownerOf(18), address(stakingContract));
        skip(2 days);

        vm.startPrank(userC); // 8 and 18
        // revert for random token ID
        vm.expectRevert(abi.encodeWithSelector(NoTokenRecordFound.selector));
        stakingContract.unstake(2);

        // success case
        vm.expectEmit(true, true, false, false);
        emit Unstake(userC, 18);
        stakingContract.unstake(18);
        assertEq(stakingContract.rewardToken().balanceOf(userC), 20e18);
        assertEq(nft.ownerOf(18), userC);

        // revert since nft has been withdrawn
        vm.expectRevert(abi.encodeWithSelector(NoTokenRecordFound.selector));
        stakingContract.unstake(18);
        vm.expectRevert(abi.encodeWithSelector(NoTokenRecordFound.selector));
        stakingContract.claimRewards(2);

        // // try staking again
        nft.approve(address(stakingContract), 18);
        stakingContract.stake(18);
        skip(12 hours);

        // // success case
        vm.expectEmit(true, true, false, true);
        emit Claim(userC, 18, 5e18);
        stakingContract.claimRewards(18);
        assertEq(stakingContract.rewardToken().balanceOf(userC), 20e18 + 5e18);

        vm.stopPrank();
    }
}
