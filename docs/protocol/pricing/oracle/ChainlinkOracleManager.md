## `ChainlinkOracleManager`

Once an oracle is added for an asset it can't be changed!

### `constructor(address _config)` (public)

### `setExpiryPriceInRegistry(address _asset, uint256 _expiryTimestamp, uint256 _roundId)` (external)

Get the expiry price from oracle and store it in the price registry so we have a copy

### `getCurrentPrice(address _asset) → uint256` (external)

Get the expiry price from oracle and store it in the price registry so we have a copy

### `ChainlinkPriceSubmission(address asset, uint256 expiryTimestamp, uint256 price, uint256 roundId, address oracle)`
