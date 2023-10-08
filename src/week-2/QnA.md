## ERC721A

The major difference between ERC721A and ERC721 is that ERC721A is optimized for batch minting at the expense of
increasing gas cost for `transferFrom` and `safeTransferFrom`.

#### How does ERC721A save gas?

In ERC721, a `safeMint` modifies the ownership state from 0 to non-zero for each token ID (~ 20k gas per token ID).
During a batch minting, ERC721A only modifies the state for the first token and leaves the state as 0 for consecutive
tokens. That's why their batch minting gas cost is the same as minting one token. This approach works when the
assumption is that during minting, the token IDs are consecutive and not random.

#### Where does it add cost?

Since ERC721 only sets the owner of the first token ID during batch minting, the owner of consecutive token IDs in that
batch is set to 0. That's why when these tokens, except the first token in each batch, are transferred for the first
time, they consume an extra ~20k gas for updating a 0 owner value to non-zero. The drawback is that the same user who
saved cost while minting will pay for it when they want to sell or transfer to another address.

#### Why shouldn’t ERC721A enumerable’s implementation be used on-chain?

I assume the question is about when ERC721A should not be used on-chain.

ERC721A works on the assumption that an account can only mint consecutive token IDs. That means it cannot be used
on-chain if the users are allowed to mint a random token ID.

Since the first `transfer` call carries an additional 20k gas per token ID, it is not appropriate to use it when users
are expected to transfer them anytime soon such as gaming assets.

## Wrapped NFT

#### Besides the examples listed in the code and the reading, what might the wrapped NFT pattern be used for?

1. Index token: a wrapped NFT can represent a basket of NFTs
2. Masking a non-ERC721 into an ERC721: Cryptokitties and Cryptopunks are not an ERC721 compliant NFTs. An NFT wrapper
   can be used to wrap non-ERC721-compliant NFTs into ERC721-compliant NFTs.
3. Extensibility: A wrapping mechanism can be used to extend new functionalities to an existing NFT. For example, to
   enforce royalties at the smart contract level.

## Use of solidity events by NFT marketplaces

#### How can OpenSea quickly determine which NFTs an address owns if most NFTs don’t use ERC721 enumerable? Explain how you would accomplish this if you were creating an NFT marketplace

When an NFT is sold, transferred or minted, it emits a `Transfer` event with `from`, `to` and `tokenId` as indexed for
queries. OpenSea keeps listening to `Transfer`` events on all NFT contracts to identify who is the current owner of a
particular token ID.

To be able to fast query Blockchain for events is essentially what helps the marketplace to be able to track NFT
transfers instantly even if they don't occur through their platform.

Below is an example of how you can do it using [ethers](https://docs.ethers.org/) library:

```javascript
abi = ["event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId)"];
const contract = new Contract(contract_address, abi, provider);

//Begin listening to the Transfer event
contract.on("Transfer", (from, to, tokenId, event) => {
  /** So every time a Transfer event is emitted by the contract_address, you can
   * use the log to update your database entries and instantly know the address
   * of the new owner
   */
});
```

Similarly, you can also query all historical events using the `queryFilter` and `filters` methods on the `Contract`
object.
