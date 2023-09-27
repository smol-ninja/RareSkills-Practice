SafeERC20 library introduces the following functions for ERC20:

1. `safeTransfer` and `safeTransferFrom`

`transfer` and `transferFrom` returns `false` and does not revert if transfer fails. It can lead to untended behaviour
if return data is not handled properly. SafeERC20 introduces `safeTransfer` and `safeTransferFrom` which revert if
internal `transfer` and `transferFrom` returns `false`.

2. `safeIncreaseAllowance` and `safeDecreaseAllowance`

`approve` function can override previous allowances. SafeERC20 introduces `safeIncreaseAllowance` which **increases**
allowances instead of overriding it.
