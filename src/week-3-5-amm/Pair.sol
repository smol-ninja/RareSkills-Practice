// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { UD60x18, ud } from "@prb/math/UD60x18.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC3156FlashBorrower } from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";

import { PairERC20 } from "./PairERC20.sol";

/**
 * @dev it uses UD60x18 library for fixed point arithmetic. It has 60 integers and 18 decimal points.
 */
contract Pair is PairERC20 {
    using SafeERC20 for IERC20;

    // events
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Sync(uint112 reserve0, uint112 reserve1);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    // errors
    error UnsupportedToken();
    error FlashLoanFailed();
    error Overflow();
    error MinimumLiquidity();
    error InsufficientLiquidity();
    error ZeroOutput();
    error InsufficientReserve();
    error ZeroInput();
    error XYK();

    // MINIMUM_LIQUIDITY is the amount of LP tokens that gets burned on the first liquidity provision
    // to make the totalSupply parmanently greater than zero
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    // swap fee = 0.3%
    uint256 public constant FEE_BPS = 30;
    uint256 private constant UINT112_MAX = type(uint112).max;

    address public immutable token0;
    address public immutable token1;
    address public immutable factory;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    // fit in a single slot
    uint112 private _reserve0;
    uint112 private _reserve1;
    uint32 private _blockTimestampLast;

    constructor(address token0_, address token1_) {
        token0 = token0_;
        token1 = token1_;
        factory = msg.sender;
    }

    function getReserves() public view returns (uint112, uint112, uint32) {
        return (_reserve0, _reserve1, _blockTimestampLast);
    }

    function kLast() public view returns (uint256) {
        return uint256(_reserve0) * uint256(_reserve1);
    }

    /**
     * @notice IERC3156FlashLender-{maxFlashLoan}
     * @param token address of token to borrow
     * @return amount maximum that user can borrow
     */
    function maxFlashLoan(address token) public view returns (uint256 amount) {
        if (token != token0 && token != token1) revert UnsupportedToken();
        amount = token == token0 ? _reserve0 : _reserve1;
    }

    /**
     * @param token address of token to borrow
     * @param amount amount of the token to borrow
     * @return fee for flashloan
     */
    function flashFee(address token, uint256 amount) public view returns (uint256 fee) {
        if (token != token0 && token != token1) revert UnsupportedToken();
        fee = (amount * FEE_BPS) / 10_000;
    }

    /**
     * @notice IERC3156FlashLender-{flashLoan}
     */
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    )
        public
        returns (bool)
    {
        address token0_ = token0; // copy into memory

        if (token != token0_ && token != token1) revert UnsupportedToken();
        // lend token. It would fail if amount > reserve
        IERC20(token).safeTransfer(address(receiver), amount);

        uint256 fee;
        unchecked {
            // cannot overflow
            fee = (amount * FEE_BPS) / 10_000;
        }
        if (receiver.onFlashLoan(msg.sender, token, amount, fee, data) != keccak256("ERC3156FlashBorrower.onFlashLoan"))
        {
            revert FlashLoanFailed();
        }
        // receive token amount + fee
        IERC20(token).safeTransferFrom(address(receiver), address(this), amount + fee);

        unchecked {
            // update reserves: cannot overflow
            if (token == token0_) _reserve0 += uint112(fee);
            else _reserve1 += uint112(fee);
        }
        return true;
    }

    /**
     * @dev function to call for supplying liquidity to the pool
     * @param to address to receive new liquidity tokens
     * @return liquidity amount of liquidity tokens to send to `to` address
     * This function expects to receive required amount of tokens to make the mint possible.
     */
    function mint(address to) public returns (uint256 liquidity) {
        // check for balance amounts and make sure they dont overflow uint112
        uint256 deposit0 = IERC20(token0).balanceOf(address(this));
        uint256 deposit1 = IERC20(token1).balanceOf(address(this));
        if (deposit0 >= UINT112_MAX || deposit1 >= UINT112_MAX) revert Overflow();

        (uint112 r0, uint112 r1) = (_reserve0, _reserve1); // copy into memory
        uint256 liquiditySupply = totalSupply(); // copy into memory

        unchecked {
            // calculate user deposits, can't overflow
            deposit0 -= uint256(r0);
            deposit1 -= uint256(r1);
        }

        if (liquiditySupply == 0) {
            // when adding liquidity for the first time: liquidity = sqrt(deposit0 * deposit1)
            liquidity = Math.sqrt(deposit0 * deposit1);
            if (liquidity < MINIMUM_LIQUIDITY) revert MinimumLiquidity();
            // mint to address(1) since minting to address(0) required overriding mint function
            _mint(address(1), MINIMUM_LIQUIDITY);

            unchecked {
                liquidity -= MINIMUM_LIQUIDITY;
            }
        } else {
            // in case deposits are not in correct proportions, compare ratios
            UD60x18 ratio0 = ud(deposit0).div(ud(r0));
            UD60x18 ratio1 = ud(deposit1).div(ud(r1));

            // cannot overflow since liquidity is bound to uint256
            if (ratio0 < ratio1) {
                liquidity = (deposit0 * liquiditySupply) / r0;
                deposit1 = (r1 * deposit0) / r0;
            } else {
                liquidity = (deposit1 * liquiditySupply) / r1;
                deposit0 = (r0 * deposit1) / r1;
            }
        }

        if (liquidity == 0) revert InsufficientLiquidity();

        unchecked {
            // update reserves. cant overflow
            _reserve0 = r0 + uint112(deposit0);
            _reserve1 = r1 + uint112(deposit1);
        }
        (r0, r1) = (_reserve0, _reserve1); // copy into memory

        // update cumulative prices
        _updateCumulativePrices(r0, r1);

        _mint(to, liquidity);

        emit Mint(to, deposit0, deposit1);
        emit Sync(r0, r1);
    }

    /**
     * @dev function to call when removing liquidity from the pool
     * @param to address to receive the removed asset
     * @return amount0 amount of token0 to send to `to` address
     * @return amount1 amount of token1 to send to `to` address
     * This function expects to receive required amount of tokens to make the burn possible.
     */
    function burn(address to) external returns (uint256 amount0, uint256 amount1) {
        uint256 burnAmount = balanceOf(address(this));

        uint256 liquiditySupply = totalSupply(); // copy into memory
        (uint112 r0, uint112 r1) = (_reserve0, _reserve1); // copy into memory

        unchecked {
            // cant overflow because uint112 * uint112 / uint256
            amount0 = (r0 * burnAmount) / liquiditySupply;
            amount1 = (r1 * burnAmount) / liquiditySupply;
        }

        unchecked {
            // update reserves. cant overflow
            _reserve0 = r0 - uint112(amount0);
            _reserve1 = r1 - uint112(amount1);
        }
        (r0, r1) = (_reserve0, _reserve1); // copy into memory

        // update cumulative prices
        _updateCumulativePrices(r0, r1);

        _burn(address(this), burnAmount);
        IERC20(token0).safeTransfer(to, amount0);
        IERC20(token1).safeTransfer(to, amount1);

        emit Burn(to, amount0, amount1, to);
        emit Sync(r0, r1);
    }

    /**
     * @dev swap function to trade between tokens
     * @param amount0Out expected amount of token0 to receive
     * @param amount1Out expected amount of token1 to receive
     * @param to address to receive the out tokens
     * This function expects to receive required amount of tokens to make the trade possible.
     */
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata) external {
        if (amount0Out == 0 && amount1Out == 0) revert ZeroOutput();
        (uint112 r0, uint112 r1) = (_reserve0, _reserve1); // copy into memory
        if (amount0Out >= r0 || amount1Out >= r1) revert InsufficientReserve();

        // check for balances
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        if (balance0 >= UINT112_MAX || balance1 >= UINT112_MAX) revert Overflow();

        uint256 amount0In;
        uint256 amount1In;
        {
            unchecked {
                if (balance0 > r0) {
                    amount0In = balance0 - r0;
                }
                if (balance1 > r1) {
                    amount1In = balance1 - r1;
                }
            }

            if (amount0In == 0 && amount1In == 0) revert ZeroInput();
            uint256 actualTransfer0Out;
            uint256 actualTransfer1Out;
            unchecked {
                // deduct fee from transfer outs and then re-calculate. Wont overflow.
                actualTransfer0Out = amount0Out - (amount0Out * FEE_BPS) / 10_000;
                actualTransfer1Out = amount1Out - (amount1Out * FEE_BPS) / 10_000;

                // update reserves
                _reserve0 = (r0 + uint112(amount0In)) - uint112(actualTransfer0Out);
                _reserve1 = (r1 + uint112(amount1In)) - uint112(actualTransfer1Out);

                // check if xy=k holds true. Lte to allow amount0In >= actualAmount0In
                if (uint256(_reserve0) * uint256(_reserve1) < uint256(r0) * uint256(r1)) revert XYK();
            }

            (r0, r1) = (_reserve0, _reserve1);
            // make transfers
            IERC20(token0).safeTransfer(to, actualTransfer0Out);
            IERC20(token1).safeTransfer(to, actualTransfer1Out);
        }

        // update cumulative prices
        _updateCumulativePrices(r0, r1);

        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
        emit Sync(r0, r1);
    }

    /**
     * @dev function to withdraw amont of tokens exceeding the reserve values
     */
    function skim(address to) external {
        uint256 diff0;
        uint256 diff1;
        unchecked {
            // cant overflow
            diff0 = IERC20(token0).balanceOf(address(this)) - _reserve0;
            diff1 = IERC20(token1).balanceOf(address(this)) - _reserve1;
        }

        IERC20(token0).safeTransfer(to, diff0);
        IERC20(token1).safeTransfer(to, diff1);
    }

    /**
     * @dev function to sync reserves to the token balances of the pool
     */
    function sync() external {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        if (balance0 >= UINT112_MAX || balance1 >= UINT112_MAX) revert Overflow();

        // update reserves
        _reserve0 = uint112(balance0);
        _reserve1 = uint112(balance1);
        (uint112 r0, uint112 r1) = (_reserve0, _reserve1); // copy into memory

        // update cumulative prices
        _updateCumulativePrices(r0, r1);

        emit Sync(r0, r1);
    }

    /**
     * @dev private function to update cumulative prices for TWAP purposes
     */
    function _updateCumulativePrices(uint112 r0, uint112 r1) private {
        uint32 timeElapsed;
        unchecked {
            timeElapsed = uint32(block.timestamp % 2 ** 32) - _blockTimestampLast;
            // its okay for _blockTimestampLast to overflow
            _blockTimestampLast = uint32(block.timestamp % 2 ** 32);
        }
        price0CumulativeLast += UD60x18.unwrap(ud(r1).div(ud(r0))) * timeElapsed;
        price1CumulativeLast += UD60x18.unwrap(ud(r0).div(ud(r1))) * timeElapsed;
    }
}
