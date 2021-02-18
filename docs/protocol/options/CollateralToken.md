## `CollateralToken`






### `constructor(address _quantConfig)` (public)

Initializes a new ERC1155 multi-token contract for representing
users' short positions




### `createCollateralToken(address _underlyingAsset, address _strikeAsset, address _oracle, uint256 _strikePrice, uint256 _expiryTime, uint256 _collateralizedFrom, bool _isCall)` (external)

Create new CollateralTokens




### `mintCollateralToken(address recipient, uint256 amount, bytes32 collateralTokenHash)` (external)





### `burnCollateralToken(address owner, uint256 amount, bytes32 collateralTokenHash)` (external)






