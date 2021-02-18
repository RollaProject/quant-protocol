## `CollateralToken`






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





