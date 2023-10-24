## vertigo-rs: Lived mutations

**BondingCurve.sol**

```solidity
// Original line
function mint(address recipient, uint256 amount) public onlySaleManager {

// Mutated line
function mint(address recipient, uint256 amount) public {
```

_Resolution_:: Add unit test for `mint()`, without which mutate survives.

**Escrow.sol**

```solidity
// Original line
if (block.timestamp < delay) revert BeforeDelay();

// Mutated Line
if (block.timestamp <= delay) revert BeforeDelay();
```

_Resolution_:: It can't fuzz inputs. This is a _false positive_.

**MerkleDiscountNFT.sol**

```solidity
// Original line
constructor(bytes32 merkleRoot\_) ERC721("MerkleDiscountNFT", "MDNFT") Ownable2Step() {

// Mutated line
constructor(bytes32 merkleRoot_) ERC721("MerkleDiscountNFT", "MDNFT")  {
```

_Resolution_:: Remove `Ownable2Step()`.

**RewardToken.sol**

```solidity
//Original line
function mint(address account, uint256 amount) public isStakingContract {

//Mutated line
function mint(address account, uint256 amount) public  {
```

_Resolution_:: add test case for unauthorized minting.

**Pair.sol**

```solidity
// Original line
_updateCumulativePrices(r0, r1);
// Mutated line:

```

_Resolution_:: Check if cumulative prices are updated correctly. There is no check and thats why mutate survives after
deleting the line.

```soldiity
// Original line
amount1In = balance1 - r1;

// Mutated line
amount1In = balance1 + r1;
```

_Resolution_:: mutate survives if reserve values are 0 during swap. Solution is to require pool to have liquidity during
swap.

```solidity
// Original line
constructor(address token0*, address token1*) PairERC20() {

// Mutated line
constructor(address token0_, address token1_)  {
```

_Resolution_:: Remove `PairERC20()` constructor as it is inherited by `Pair.sol` contract.

```solidity
// Original line
diff0 = IERC20(token0).balanceOf(address(this)) - _reserve0;

// Mutated line
diff0 = IERC20(token0).balanceOf(address(this)) + _reserve0;
```

_Resolution_:: mutate survives because it overflows during fuzz testing when `deposit value + reserve value` exceeds
`uint256`. Ensure that `deposit + reserves` of tokens doesn't exceed `uint256` during testing.

```solidity
// Original line
if (liquidity <= MINIMUM_LIQUIDITY) revert MinimumLiquidity();

// Mutated line
if (liquidity < MINIMUM_LIQUIDITY) revert MinimumLiquidity();
```

_Resolution_:: add revert if `liquidity` = 0

```solidity
// Original line
if (amount0Out > _reserve0 || amount1Out > _reserve1) revert InsufficientReserve();

// Mutated line
if (amount0Out >= _reserve0 || amount1Out > _reserve1) revert InsufficientReserve();
```

_Resolution_:: add `>=` to avoid `amountOut` equals reserve value.

```solidity
// Original line
if (uint256(_reserve0) * uint256(_reserve1) < uint256(r0) * uint256(r1)) revert XYK();

// Mutated line
if (uint256(_reserve0) * uint256(_reserve1) <= uint256(r0) * uint256(r1)) revert XYK();
```

_Resolution_:: Seems like a _false positive_.
