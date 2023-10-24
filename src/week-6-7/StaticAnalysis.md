## Slither

### True positives

1. `BojackToken.transferManager(address).newManager` (src/week-1/BondingCurve.sol#35) lacks a zero-check on:
   `_saleManager = newManager`

2. `GodMode.constructor(address).god_` (src/week-1/GodMode.sol#12) lacks a zero-check on: `_god = god_`

3. `Pair.constructor(address,address).token0_` (src/week-3-5-amm/Pair.sol#61) lacks a zero-check on: `token0 = token0_`

4. `TokenSaleManager` (src/week-1/BondingCurve.sol#40-156) should inherit from `IERC1363Receiver`

5. `TokenSaleManager` (src/week-1/BondingCurve.sol#40-156) should inherit from `IERC1363Spender`
6. `Pair` (src/week-3-5-amm/Pair.sol#15-341) should inherit from `IERC3156FlashLender`

### False positives

1. `TokenSaleManager.onApprovalReceived(address,uint256,bytes)` (src/week-1/BondingCurve.sol#131-136) uses arbitrary
   from in transferFrom: `IERC20(msg.sender).safeTransferFrom(owner,address(this),amount)`

2. `Pair.flashLoan(IERC3156FlashBorrower,address,uint256,bytes)` (src/week-3-5-amm/Pair.sol#98-131) uses arbitrary from
   in transferFrom: `IERC20(token).safeTransferFrom(address(receiver),address(this),amount + fee)`

3. `Pair._updateCumulativePrices(uint112,uint112)` (src/week-3-5-amm/Pair.sol#331-340) uses a weak PRNG:
   `_blockTimestampLast = uint32(block.timestamp % 2 ** 32)`

4. `Pair.mint(address)` (src/week-3-5-amm/Pair.sol#139-195) performs a multiplication on the result of a division:

```solidity
liquidity = (deposit0 * liquiditySupply) / r0
deposit0 = (r0 * deposit1) / r1
```

5. `Pair.mint(address)` (src/week-3-5-amm/Pair.sol#139-195) performs a multiplication on the result of a division:

```solidity
liquidity = Math.sqrt(deposit0 * deposit1)
deposit1 = (r1 * deposit0) / r0
deposit0 = (r0 * deposit1) / r1
```

6. `Prime.isPrime(uint256)` (src/week-2/PrimeNFT.sol#47-70) uses a dangerous strict equality: `n & 1 == 0 || n % 3 == 0`

7. `Prime.isPrime(uint256)` (src/week-2/PrimeNFT.sol#47-70) uses a dangerous strict equality: `n % i == 0`

8. `Pair.mint(address)` (src/week-3-5-amm/Pair.sol#139-195) uses a dangerous strict equality: `liquiditySupply == 0`

9. `Pair.swap(uint256,uint256,address,bytes)` (src/week-3-5-amm/Pair.sol#241-290) uses a dangerous strict equality:
   `amount0In == 0 && amount1In == 0`

10. Reentrancy in `Pair.burn(address)` (src/week-3-5-amm/Pair.sol#204-232):

```solidity
// External calls
_updateCumulativePrices(r0,r1)
// State variables written after the call
_burn(address(this),burnAmount)
```

11. Reentrancy in `Pair.mint(address)` (src/week-3-5-amm/Pair.sol#139-195):

```solidity
// External calls
ratio0 = ud(deposit0).div(ud(r0))
ratio1 = ud(deposit1).div(ud(r1))
```

12. Reentrancy in `Pair.mint(address)` (src/week-3-5-amm/Pair.sol#139-195):

```solidity
// External calls
ratio0 = ud(deposit0).div(ud(r0))
ratio1 = ud(deposit1).div(ud(r1))
lt(ratio0,ratio1)
_updateCumulativePrices(r0,r1)
// State variables written after the call
_mint(to,liquidity)
```

13. `Pair.swap(uint256,uint256,address,bytes).amount0In` (src/week-3-5-amm/Pair.sol#251) is a local variable never
    initialized

14. `Escrow.enterEscrow(address,IERC20,uint256).tl` (src/week-1/Escrow.sol#39) is a local variable never initialized

15. `Prime.findPrimeNFTs(address,EnumerableNFT)` (src/week-2/PrimeNFT.sol#25-39) has external calls inside a loop:
    `nfts[i] = nft.tokenOfOwnerByIndex(account,i)`

16. Reentrancy in `Escrow.enterEscrow(address,IERC20,uint256)` (src/week-1/Escrow.sol#35-50):

```solidity
// External calls
token_.safeTransferFrom(msg.sender,address(this),amount_)
// State variables written after the call
_withdrawables[seller_].push(tl)
```

17. Reentrancy in `Pair.burn(address)` (src/week-3-5-amm/Pair.sol#204-232):

```solidity
// External calls
_updateCumulativePrices(r0,r1)
IERC20(token0).safeTransfer(to,amount0)
IERC20(token1).safeTransfer(to,amount1)
// Event emitted after the call
Burn(to,amount0,amount1,to)
Sync(r0,r1)
```

18. `Escrow.settleForId(uint256)` (src/week-1/Escrow.sol#54-67) uses timestamp for dangerous comparisons:
    `block.timestamp < delay`

19. Low level call in `MerkleDiscountNFT.withdrawFunds()` (src/week-2/MerkleDiscountNFT.sol#96-100):
    `(sent) = address(owner()).call{value: address(this).balance}()`

20. Variable `Pair.swap(uint256,uint256,address,bytes).actualTransfer0Out` (src/week-3-5-amm/Pair.sol#264) is too
    similar to `Pair.swap(uint256,uint256,address,bytes).actualTransfer1Out`

21. `Factory._computeAddress(address,address)` (src/week-3-5-amm/Factory.sol#78-93) uses literals with too many digits:
    `pair = address(uint160(uint256(keccak256(bytes)(abi.encodePacked(0xff,address(this),SALT,keccak256(bytes)(abi.encodePacked(type()(Pair).creationCode,abi.encode(token0,token1))))))))`
