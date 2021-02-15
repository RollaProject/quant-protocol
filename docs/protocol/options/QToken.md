## `QToken`

### `constructor(address _quantConfig, address _underlyingAsset, address _strikeAsset, address _oracle, uint256 _strikePrice, uint256 _expiryTime, bool _isCall)` (public)

Configures the parameters of a new option token

### `mint(address account, uint256 amount)` (external)

mint option token for an account

Controller only method where access control is taken care of by \_beforeTokenTransfer hook

### `burn(address account, uint256 amount)` (external)

burn option token from an account.

Controller only method where access control is taken care of by \_beforeTokenTransfer hook

### `_qTokenName(address _underlyingAsset, address _strikeAsset, uint256 _strikePrice, uint256 _expiryTime, bool _isCall) → string tokenName` (internal)

generates the name for an option

### `_qTokenSymbol(address _underlyingAsset, address _strikeAsset, uint256 _strikePrice, uint256 _expiryTime, bool _isCall) → string tokenSymbol` (internal)

generates the symbol for an option

### `_getOptionType(bool _isCall) → string, string` (internal)

get the string representation of the option type

### `_displayedStrikePrice(uint256 _strikePrice) → string` (internal)

convert the option strike price scaled to a human readable value

### `_uintToChars(uint256 number) → string` (internal)

get the representation of a number using 2 characters, adding a leading 0 if it's one digit,
and two trailing digits if it's a 3 digit number

### `_slice(string _s, uint256 _start, uint256 _end) → string` (internal)

cut a string into string[start:end]

### `_getMonth(uint256 _month) → string, string` (internal)

get the string representations of a month
