## `ProviderOracleManager`

Once an oracle is added for an asset it can't be changed!

### `constructor(address _config)` (internal)

### `addAssetOracle(address _asset, address _oracle)` (external)

Add an asset to the oracle manager with its corresponding oracle address

Once this is set for an asset, it can't be changed or removed

### `setExpiryPriceInRegistry(address _asset, uint256 _expiryTimestamp, uint256 _roundId)` (external)

Get the expiry price from oracle and store it in the price registry so we have a copy

### `getAssetsLength() → uint256` (external)

Get the total number of assets managed by the oracle manager

### `getCurrentPrice(address _asset) → uint256` (external)

Function that should be overridden which should return the current price of an asset from the provider
