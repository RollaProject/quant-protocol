## `CollateralToken`

Can be used by owners to claim their collateral


This is a multi-token contract that implements the ERC1155 token standard:
https://eips.ethereum.org/EIPS/eip-1155


### `constructor(address _quantConfig)` (public)

Initializes a new ERC1155 multi-token contract for representing
users' short positions




### `createCollateralToken(address _underlyingAsset, address _strikeAsset, address _oracle, uint256 _strikePrice, uint256 _expiryTime, uint256 _collateralizedFrom, bool _isCall) → uint256 id` (external)

Create new CollateralTokens


Should also be used elsewhere where getting a CollateralToken id from
its parameters is necessary


### `mintCollateralToken(address recipient, uint256 amount, uint256 collateralTokenId)` (external)

Mint CollateralTokens for a given account




### `burnCollateralToken(address owner, uint256 amount, uint256 collateralTokenId)` (external)

Mint CollateralTokens for a given account




### `mintCollateralTokenBatch(address recipient, uint256[] ids, uint256[] amounts)` (external)

Batched minting of multiple CollateralTokens for a given account


Should be used when minting multiple CollateralTokens for a single user,
i.e., when a user buys more than one short position through the interface
ids and amounts must have the same length

### `burnCollateralTokenBatch(address owner, uint256[] ids, uint256[] amounts)` (external)

Batched burning of of multiple CollateralTokens from a given account


Should be used when burning multiple CollateralTokens for a single user,
i.e., when a user sells more than one short position through the interface
ids and amounts shoud have the same length


