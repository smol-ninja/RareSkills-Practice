// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Pair } from "./Pair.sol";

contract Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    // random salt generated for create2
    bytes32 private constant SALT = hex"597ff892197fdc5c0ef4e2ee49fc7c4e990dfc72fae590dd8a6ab49c343cdf4c";
    address[] private _allPairs;

    /**
     * @dev get unique pair address for (tokenA, tokenB) and verifies if it exists in the list
     * @param tokenA address of tokenA
     * @param tokenB address of tokenB
     * @return pair address
     */
    function getPair(address tokenA, address tokenB) external view returns (address pair) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        address expectedPair = _computeAddress(token0, token1);

        uint256 pairsLength = _allPairs.length;

        unchecked {
            for (uint256 i; i < pairsLength; ++i) {
                if (_allPairs[i] == expectedPair) {
                    return expectedPair;
                }
            }
        }
        return address(0);
    }

    /**
     * @param index to look at
     * @return pair at index from the list
     */
    function allPairs(uint256 index) external view returns (address pair) {
        pair = _allPairs[index];
    }

    /**
     * @return length of the _allPairs array
     */
    function allPairsLength() external view returns (uint256 length) {
        length = _allPairs.length;
    }

    /**
     * @dev creates a Pair contract for given (tokenA, tokenB) unique pair.
     * @param tokenA address of tokenA
     * @param tokenB address of tokenB
     * @return pair address
     */
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);

        // deploy contract using create2
        Pair p = new Pair{salt: SALT}(token0, token1);
        pair = address(p);
        _allPairs.push(pair);

        // log is 1 for first pair, 2 for second pair and so on.
        uint256 log = _allPairs.length;

        emit PairCreated(token0, token1, pair, log);
    }

    function _sortTokens(address tokenA, address tokenB) private pure returns (address token0, address token1) {
        if (tokenB < tokenA) {
            return (tokenB, tokenA);
        }

        return (tokenA, tokenB);
    }

    function _computeAddress(address token0, address token1) private view returns (address pair) {
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"FF",
                            address(this),
                            SALT,
                            keccak256(abi.encodePacked(type(Pair).creationCode, abi.encode(token0, token1)))
                        )
                    )
                )
            )
        );
    }
}
