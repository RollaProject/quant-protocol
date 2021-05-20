## `IQToken`

Can be used by owners to exercise their options

Every option long position is an ERC20 token: https://eips.ethereum.org/EIPS/eip-20

### `mint(address account, uint256 amount)` (external)

mint option token for an account

### `burn(address account, uint256 amount)` (external)

burn option token from an account.

### `quantConfig() → contract IQuantConfig` (external)

Address of system config.

### `underlyingAsset() → address` (external)

Address of the underlying asset. WETH for ethereum options.

### `strikeAsset() → address` (external)

Address of the strike asset. Quant Web options always use USDC.

### `oracle() → address` (external)

Address of the oracle to be used with this option

### `strikePrice() → uint256` (external)

The strike price for the token with the strike asset precision.

### `expiryTime() → uint256` (external)

UNIX time for the expiry of the option

### `isCall() → bool` (external)

True if the option is a CALL. False if the option is a PUT.

### `getOptionPriceStatus() → enum PriceStatus` (external)

Get the price status of the option.

### `QTokenMinted(address account, uint256 amount)`

event emitted when QTokens are minted

### `QTokenBurned(address account, uint256 amount)`

event emitted when QTokens are burned
