// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

contract Pair {
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Sync(uint112 reserve0, uint112 reserve1);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );

    address immutable private _TOKEN0;
    address immutable private _TOKEN1;
    address immutable private _FACTORY;
    uint112 private _reserve0;
    uint112 private _reserve1;
    uint32 private _blockTimestampLast;

    constructor(address token0_, address token1_) {
        _TOKEN0 = token0_;
        _TOKEN1 = token1_;
        _FACTORY = msg.sender;
    }

    /*********************************/
    /*****       READ ONLY       *****/
    /*********************************/

    function MINIMUM_LIQUIDITY() external pure returns (uint) {
        return 1000;
    }

    function factory() external view returns (address) {
        return _FACTORY;
    }

    function token0() external view returns (address) {
        return _TOKEN0;
    }

    function token1() external view returns (address) {
        return _TOKEN1;
    }

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) {
        return (_reserve0, _reserve1, _blockTimestampLast);
    }

    function price0CumulativeLast() external view returns (uint) {

    }

    function price1CumulativeLast() external view returns (uint) {

    }

    function kLast() external view returns (uint) {
        return _reserve0 * _reserve1;
    }

    /*********************************/
    /*****    STATE CHANGING     *****/
    /*********************************/

    function mint(address to) external returns (uint liquidity) {

    }

    function burn(address to) external returns (uint amount0, uint amount1) {

    }

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external {

    }

    function skim(address to) external {
        
    }

    function sync() external {

    }
}