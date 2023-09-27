Problems that led to the introduction of ERC777:

1. An accidental transfer of tokens to another contract or the token contract itself can lead to loss of funds.

ERC777 introduces hooks that can be called before and after transfer. It can be used to prevent accidental transfer of
tokens to unintended contracts.

2. Infinite `approve` can lead to exploits.

ERC777 introduced `tokensReceived` that can be trigerred by making a direct `transfer` of tokens to the contract
avoiding giving approvals.

3. Approvals are always required even in case of trusted contracts.

The introduction of `operators` tried to eliminate approvals by maintaining a list of operators within the contract.
Authorized operators can move tokens without the need of `approve` function.

Problems that led to the introduction of ERC1363:

1. ERC20 requires `approve` and `transferFrom` when interacting with contracts
2. Inability of ERC20 to trigger callback functions.

ERC1636 tries to merge these two calls into one through `transferAndCall` and `approveAndCall`. You can also invoke
functions on the target address to execute calls.

Issues with ERC777 are the added complexity over ERC20 standard. ERC20 standard is basic while ERC777 introduces hook
and new functions which requires extra care. Also, callback hooks can lead to reentrancy attacks if not handled well.
