## `IChainlinkOracleManager`

### `setExpiryPriceInRegistryByRound(address _asset, uint256 _expiryTimestamp, uint256 _roundIdAfterExpiry)` (external)

Set the price of an asset at a timestamp using a chainlink round id

### `fallbackPeriodSeconds() → uint256` (external)

### `searchRoundToSubmit(address _asset, uint256 _expiryTimestamp) → uint80` (external)

Searches for the round in the asset oracle immediately after the expiry timestamp

### `PriceRegistrySubmission(address asset, uint256 expiryTimestamp, uint256 price, uint256 expiryRoundId, address priceSubmitter, bool isFallback)`
