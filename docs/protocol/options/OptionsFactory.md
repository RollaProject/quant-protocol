## `OptionsFactory`

Creates tokens for long (QToken) and short (CollateralToken) positions

This contract follows the factory design pattern

### `constructor(address quantConfig_, address collateralToken_)` (public)

Initializes a new options factory

### `createOption(address _underlyingAsset, address _strikeAsset, address _oracle, uint256 _strikePrice, uint256 _expiryTime, bool _isCall) → address newQToken, uint256 newCollateralTokenId` (external)

Creates new options (QToken + CollateralToken)

The CREATE2 opcode is used to deterministically deploy new QTokens

### `getTargetCollateralTokenId(address _underlyingAsset, address _strikeAsset, address _oracle, uint256 _strikePrice, uint256 _expiryTime, uint256 _collateralizedFrom, bool _isCall) → uint256` (public)

get the id that a CollateralToken with the given parameters would have

### `getCollateralToken(address _underlyingAsset, address _strikeAsset, address _oracle, uint256 _strikePrice, uint256 _expiryTime, uint256 _collateralizedFrom, bool _isCall) → uint256` (public)

get the CollateralToken id for an already created CollateralToken,
if no QToken has been created with these parameters, it will return 0

### `getTargetQTokenAddress(address _underlyingAsset, address _strikeAsset, address _oracle, uint256 _strikePrice, uint256 _expiryTime, bool _isCall) → address` (public)

get the address at which a new QToken with the given parameters would be deployed
return the exact address the QToken will be deployed at with OpenZeppelin's Create2
library computeAddress function

### `getQToken(address _underlyingAsset, address _strikeAsset, address _oracle, uint256 _strikePrice, uint256 _expiryTime, bool _isCall) → address` (public)

get the QToken address for an already created QToken, if no QToken has been created
with these parameters, it will return the zero address

### `getOptionsLength() → uint256` (external)

get the total number of options created by the factory

### `_qTokenHash(address _underlyingAsset, address _strikeAsset, address _oracle, uint256 _strikePrice, uint256 _expiryTime, bool _isCall) → bytes32` (internal)

Returns a unique option hash based on its parameters

### `OptionCreated(address qTokenAddress, address creator, address underlying, address strike, address oracle, uint256 strikePrice, uint256 expiry, uint256 collateralTokenId, bool isCall)`

emitted when the factory creates a new option
