## `OptionsFactory`

### `constructor(address quantConfig_)` (public)

Initializes a new options factory

### `createOption(address _underlyingAsset, address _strikeAsset, address _oracle, uint256 _strikePrice, uint256 _expiryTime, bool _isCall) → address` (external)

Creates new QTokens

The CREATE2 opcode is used to deterministically deploy new QTokens

### `getTargetQTokenAddress(address _underlyingAsset, address _strikeAsset, address _oracle, uint256 _strikePrice, uint256 _expiryTime, bool _isCall) → address` (external)

get the address at which a new QToken with the given parameters would be deployed
return the exact address the QToken will be deployed at with OpenZeppelin's Create2
library computeAddress function

### `getQToken(address _underlyingAsset, address _strikeAsset, address _oracle, uint256 _strikePrice, uint256 _expiryTime, bool _isCall) → address` (external)

get the QToken address for an already created QToken, if no QToken has been created
with these parameters, it will return the zero address

### `getOptionsLength() → uint256` (external)

get the total number of options created by the factory

### `_optionHash(address _underlyingAsset, address _strikeAsset, address _oracle, uint256 _strikePrice, uint256 _expiryTime, bool _isCall) → bytes32` (internal)

Returns a unique option hash based on its parameters

### `OptionCreated(address optionTokenAddress, address creator, address underlying, address strike, address oracle, uint256 strikePrice, uint256 expiry, bool isCall)`

emitted when the factory creates a new option
