## `ChainlinkOracleManager`

Once an oracle is added for an asset it can't be changed!




### `constructor(address _config, uint256 _fallbackPeriodSeconds)` (public)





### `setExpiryPriceInRegistryByRound(address _asset, uint256 _expiryTimestamp, uint256 _roundIdAfterExpiry)` (external)

Set the price of an asset at a timestamp using a chainlink round id




### `_setExpiryPriceInRegistryByRound(address _asset, uint256 _expiryTimestamp, uint256 _roundIdAfterExpiry)` (internal)

Get the expiry price from chainlink asset oracle and store it in the price registry




### `setExpiryPriceInRegistry(address _asset, uint256 _expiryTimestamp, bytes)` (external)

Searches for the correct price from chainlink and publishes it to the price registry




### `searchRoundToSubmit(address _asset, uint256 _expiryTimestamp) → uint80` (public)

Searches for the round in the asset oracle immediately after the expiry timestamp




### `_binarySearchStep(contract IEACAggregatorProxy aggregator, uint256 _expiryTimestamp, uint80 _firstRoundProxy, uint80 _lastRoundProxy) → struct ChainlinkOracleManager.BinarySearchResult` (internal)

Performs a binary search step between the first and last round in the aggregator proxy




### `getCurrentPrice(address _asset) → uint256` (external)

Get the current price of the asset from its oracle




### `setExpiryPriceInRegistryFallback(address _asset, uint256 _expiryTimestamp, uint256 _price)` (external)

Fallback mechanism to submit price to the registry after the
lock up period is passed with no successful submission




### `_toUint80(uint256 _value) → uint80` (internal)



Returns the downcasted uint80 from uint256, reverting on
overflow (when the input is greater than largest uint80).

Counterpart to Solidity's `uint80` operator.

Requirements:

- input must fit into 80 bits


### `PriceRegistrySubmission(address asset, uint256 expiryTimestamp, uint256 price, uint256 expiryRoundId, address priceSubmitter, bool isFallback)`





