// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IERC721Receiver } from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { RewardToken } from "./RewardToken.sol";

contract StakingContract is IERC721Receiver {
    uint32 private constant _TWENTY_FOUR_HOURS = 24 hours;
    uint64 public constant DAILY_REWARDS = 10e18;
    RewardToken public immutable rewardToken;
    IERC721 public immutable merkleDiscountNft;

    mapping(address account => mapping(uint256 tokenId => uint256 timestamp)) private _userRecords;

    // event names
    event Stake(address, uint256);
    event Unstake(address, uint256);
    event Claim(address, uint256, uint256);

    // error names
    error NoTokenRecordFound();

    /**
     * @dev deploying this contract also deploys reward token
     * @param nftAddress address of the MerkleDiscountNFT
     */
    constructor(IERC721 nftAddress) {
        rewardToken = new RewardToken();
        merkleDiscountNft = nftAddress;
    }

    /**
     * @dev stake by calling this function or directly transfer NFT using `safeTransferFrom`
     * @param tokenId NFT token ID
     */
    function stake(uint256 tokenId) external {
        merkleDiscountNft.safeTransferFrom(msg.sender, address(this), tokenId);

        emit Stake(msg.sender, tokenId);
    }

    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata
    )
        public
        override
        returns (bytes4 selector_)
    {
        // updates `_userRecords` map and set current timestamp
        _userRecords[from][tokenId] = block.timestamp;

        selector_ = IERC721Receiver.onERC721Received.selector;
    }

    /**
     * @param tokenId NFT token ID
     */
    function unstake(uint256 tokenId) external {
        uint256 totalRewards = _calculateRewards(tokenId);

        // delete _userRecords
        delete _userRecords[msg.sender][tokenId];

        // mint reward token to user address
        rewardToken.mint(msg.sender, totalRewards);

        // send NFT to user address
        merkleDiscountNft.safeTransferFrom(address(this), msg.sender, tokenId);

        emit Unstake(msg.sender, tokenId);
    }

    /**
     * @dev this sets timestamp to current timestamp
     * @param tokenId NFT token ID
     */
    function claimRewards(uint256 tokenId) external {
        uint256 totalRewards = _calculateRewards(tokenId);

        // update timestamp state to current timestamp
        _userRecords[msg.sender][tokenId] = block.timestamp;

        // mint reward token to user address
        rewardToken.mint(msg.sender, totalRewards);

        emit Claim(msg.sender, tokenId, totalRewards);
    }

    /**
     * @dev daily_rewards * (current time - previous time) / 24 hours
     * @param tokenId previously stored timestamp
     * @return rewards of the user since last claim
     */
    function _calculateRewards(uint256 tokenId) private view returns (uint256 rewards) {
        uint256 storedTimestamp = _userRecords[msg.sender][tokenId];

        // revert if tokenid does not exist in the map for this user
        if (storedTimestamp == 0) revert NoTokenRecordFound();

        // do the maths here
        unchecked {
            rewards = (DAILY_REWARDS * (block.timestamp - storedTimestamp)) / _TWENTY_FOUR_HOURS;
        }
    }
}
