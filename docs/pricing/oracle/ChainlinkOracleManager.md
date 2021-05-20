## `ChainlinkOracleManager`

Once an oracle is added for an asset it can't be changed!

### `constructor(address _config, uint256 _fallbackPeriodSeconds)` (public)

### `setExpiryPriceInRegistryByRound(address _asset, uint256 _expiryTimestamp, uint256 _roundIdAfterExpiry)` (external)

Set the price of an asset at a timestamp using a chainlink round id

### `setExpiryPriceInRegistry(address _asset, uint256 _expiryTimestamp, bytes)` (external)

Get the expiry price from oracle and store it in the price registry so we have a copy

### `setExpiryPriceInRegistryFallback(address _asset, uint256 _expiryTimestamp, uint256 _price)` (external)

Fallback mechanism to submit price to the registry (should enforce a locking period)

### `getCurrentPrice(address _asset) → uint256` (external)

Function that should be overridden which should return the current price of an asset from the provider

### `searchRoundToSubmit(address _asset, uint256 _expiryTimestamp) → uint80` (public)

Searches for the round in the asset oracle immediately after the expiry timestamp

### `_setExpiryPriceInRegistryByRound(address _asset, uint256 _expiryTimestamp, uint256 _roundIdAfterExpiry)` (internal)

Get the expiry price from chainlink asset oracle and store it in the price registry

### `_binarySearchStep(contract IEACAggregatorProxy aggregator, uint256 _expiryTimestamp, uint80 _firstRoundProxy, uint80 _lastRoundProxy) → struct ChainlinkOracleManager.BinarySearchResult` (internal)

Performs a binary search step between the first and last round in the aggregator proxy

### `_toUint80(uint256 _value) → uint80` (internal)

Returns the downcasted uint80 from uint256, reverting on
overflow (when the input is greater than largest uint80).

Counterpart to Solidity's `uint80` operator.

Requirements:

- input must fit into 80 bits
