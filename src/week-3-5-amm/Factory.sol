// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Pair } from "./Pair.sol";

contract Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    bytes32 constant private _SALT = hex'597ff892197fdc5c0ef4e2ee49fc7c4e990dfc72fae590dd8a6ab49c343cdf4c';
    address[] private _allPairs;

    /*********************************/
    /*****      CONSTRUCTOR      *****/
    /*********************************/

    constructor() { }

    /*********************************/
    /*****       READ ONLY       *****/
    /*********************************/

    function getPair(address tokenA, address tokenB) external view returns (address pair) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        address expectedPair = _create2Pair(token0, token1);

        uint pairsLength = _allPairs.length;

        unchecked {
            for (uint i; i < pairsLength; ++i) {
                if (_allPairs[i] == expectedPair) {
                    return pair;
                }
            }    
        }
        return address(0);
    }

    function allPairs(uint index) external view returns (address pair) {
        pair = _allPairs[index];
    }

    function allPairsLength() external view returns (uint len) {
        len = _allPairs.length;
    }

    /*********************************/
    /*****    STATE CHANGING     *****/
    /*********************************/

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        pair = _create2Pair(token0, token1);
        Pair deployedPair = new Pair{salt: _SALT}(token0, token1);
        require(address(deployedPair) == pair);
        _allPairs.push(pair);

        uint log;
        unchecked {
            log = _allPairs.length + 1;
        }

        emit PairCreated(token0, token1, pair, log);
    }

    /*********************************/
    /*********    PRIVATE    *********/
    /*********************************/

    function _sortTokens(address tokenA, address tokenB) private pure returns (address token0, address token1) {
        if (tokenA <= tokenB) {
            token0 = tokenA;
            token1 = tokenB;
        } else {
            token0 = tokenB;
            token1 = tokenA;
        }
    }

    function _create2Pair(address token0, address token1) private view returns (address pair) {
        pair = address(uint160(uint(keccak256(abi.encodePacked(
            hex'FF',
            address(this),
            _SALT,
            keccak256(abi.encodePacked(
                type(Pair).creationCode,
                abi.encode(token0, token1)
            ))
        )))));
    }
}