## `IProviderOracleManager`

Once an oracle is added for an asset it can't be changed!

### `addAssetOracle(address _asset, address _oracle)` (external)

Add an asset to the oracle manager with its corresponding oracle address

Once this is set for an asset, it can't be changed or removed

### `setExpiryPriceInRegistry(address _asset, uint256 _expiryTimestamp, bytes _calldata)` (external)

Get the expiry price from oracle and store it in the price registry so we have a copy

### `config() → contract IQuantConfig` (external)

quant central configuration

### `assetOracles(address) → address` (external)

asset address => oracle address

### `assets(uint256) → address` (external)

exhaustive list of asset addresses in map

### `getAssetOracle(address _asset) → address` (external)

Get the oracle address associated with an asset

### `getAssetsLength() → uint256` (external)

Get the total number of assets managed by the oracle manager

### `getCurrentPrice(address _asset) → uint256` (external)

Function that should be overridden which should return the current price of an asset from the provider

### `OracleAdded(address asset, address oracle)`
