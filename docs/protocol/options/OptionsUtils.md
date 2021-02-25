## `OptionsUtils`

This library must be deployed and linked while deploying contracts that use it

### `getTargetQTokenAddress(address _quantConfig, address _underlyingAsset, address _strikeAsset, address _oracle, uint256 _strikePrice, uint256 _expiryTime, bool _isCall) → address` (internal)

get the address at which a new QToken with the given parameters would be deployed
return the exact address the QToken will be deployed at with OpenZeppelin's Create2
library computeAddress function

### `getTargetCollateralTokenId(contract CollateralToken _collateralToken, address _quantConfig, address _underlyingAsset, address _strikeAsset, address _oracle, uint256 _strikePrice, uint256 _expiryTime, uint256 _collateralizedFrom, bool _isCall) → uint256` (internal)

get the id that a CollateralToken with the given parameters would have

### `qTokenHash(address _underlyingAsset, address _strikeAsset, address _oracle, uint256 _strikePrice, uint256 _expiryTime, bool _isCall) → bytes32` (internal)

Returns a unique option hash based on its parameters
