## `OptionsFactory`

Creates tokens for long (QToken) and short (CollateralToken) positions


This contract follows the factory design pattern


### `constructor(address quantConfig_, address collateralToken_)` (public)

Initializes a new options factory




### `createOption(address _underlyingAsset, address _strikeAsset, address _oracle, uint256 _strikePrice, uint256 _expiryTime, bool _isCall) → address newQToken, uint256 newCollateralTokenId` (external)

Creates new options (QToken + CollateralToken)


The CREATE2 opcode is used to deterministically deploy new QTokens


### `getCollateralToken(address _underlyingAsset, address _strikeAsset, address _oracle, uint256 _strikePrice, uint256 _expiryTime, uint256 _collateralizedFrom, bool _isCall) → uint256` (public)

get the CollateralToken id for an already created CollateralToken,
if no QToken has been created with these parameters, it will return 0




### `getQToken(address _underlyingAsset, address _strikeAsset, address _oracle, uint256 _strikePrice, uint256 _expiryTime, bool _isCall) → address` (public)

get the QToken address for an already created QToken, if no QToken has been created
with these parameters, it will return the zero address




### `getOptionsLength() → uint256` (external)

get the total number of options created by the factory





### `OptionCreated(address qTokenAddress, address creator, address underlying, address strike, address oracle, uint256 strikePrice, uint256 expiry, uint256 collateralTokenId, bool isCall)`

emitted when the factory creates a new option



