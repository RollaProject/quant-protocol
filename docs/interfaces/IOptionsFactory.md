## `IOptionsFactory`

### `createOption(address _underlyingAsset, address _strikeAsset, address _oracle, uint256 _strikePrice, uint256 _expiryTime, bool _isCall)` (external)

Creates new options (QToken + CollateralToken)

The CREATE2 opcode is used to deterministically deploy new QTokens

### `qTokens(uint256) → address` (external)

array of all the created QTokens

### `quantConfig() → contract IQuantConfig` (external)

### `collateralToken() → contract ICollateralToken` (external)

### `qTokenAddressToCollateralTokenId(address) → uint256` (external)

### `getTargetQTokenAddress(address _underlyingAsset, address _strikeAsset, address _oracle, uint256 _strikePrice, uint256 _expiryTime, bool _isCall) → address` (external)

get the address at which a new QToken with the given parameters would be deployed
return the exact address the QToken will be deployed at with OpenZeppelin's Create2
library computeAddress function

### `getTargetCollateralTokenId(address _underlyingAsset, address _strikeAsset, address _oracle, address _qTokenAsCollateral, uint256 _strikePrice, uint256 _expiryTime, bool _isCall) → uint256` (external)

get the id that a CollateralToken with the given parameters would have

### `getCollateralToken(address _underlyingAsset, address _strikeAsset, address _oracle, address _qTokenAsCollateral, uint256 _strikePrice, uint256 _expiryTime, bool _isCall) → uint256` (external)

get the CollateralToken id for an already created CollateralToken,
if no QToken has been created with these parameters, it will return 0

### `getQToken(address _underlyingAsset, address _strikeAsset, address _oracle, uint256 _strikePrice, uint256 _expiryTime, bool _isCall) → address` (external)

get the QToken address for an already created QToken, if no QToken has been created
with these parameters, it will return the zero address

### `getOptionsLength() → uint256` (external)

get the total number of options created by the factory

### `isQToken(address) → bool` (external)

checks if an address is a QToken

### `OptionCreated(address qTokenAddress, address creator, address underlying, address strike, address oracle, uint256 strikePrice, uint256 expiry, uint256 collateralTokenId, uint256 allOptionsLength, bool isCall)`

emitted when the factory creates a new option
