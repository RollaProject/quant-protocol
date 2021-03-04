## `QToken`

Can be used by owners to exercise their options

Every option long position is an ERC20 token: https://eips.ethereum.org/EIPS/eip-20

### `constructor(address _quantConfig, address _underlyingAsset, address _strikeAsset, address _oracle, uint256 _strikePrice, uint256 _expiryTime, bool _isCall)` (public)

Configures the parameters of a new option token

### `mint(address account, uint256 amount)` (external)

mint option token for an account

### `burn(address account, uint256 amount)` (external)

burn option token from an account.

### `_qTokenName(address _underlyingAsset, address _strikeAsset, uint256 _strikePrice, uint256 _expiryTime, bool _isCall) → string tokenName` (internal)

generates the name for an option

### `_qTokenSymbol(address _underlyingAsset, address _strikeAsset, uint256 _strikePrice, uint256 _expiryTime, bool _isCall) → string tokenSymbol` (internal)

generates the symbol for an option

### `_getOptionType(bool _isCall) → string, string` (internal)

get the string representation of the option type

### `_displayedStrikePrice(uint256 _strikePrice) → string` (internal)

convert the option strike price scaled to a human readable value

### `_uintToChars(uint256 _number) → string` (internal)

get the representation of a number using 2 characters, adding a leading 0 if it's one digit,
and two trailing digits if it's a 3 digit number

### `_slice(string _s, uint256 _start, uint256 _end) → string` (internal)

cut a string into string[start:end]

### `_getMonth(uint256 _month) → string, string` (internal)

get the string representations of a month

### `getOptionPriceStatus() → enum QToken.PriceStatus` (external)

Get the price status of the option.

### `QTokenMinted(address account, uint256 amount)`

event emitted when QTokens are minted

### `QTokenBurned(address account, uint256 amount)`

event emitted when QTokens are burned
