// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../../../external/chainlink/IEACAggregatorProxy.sol";
import "../PriceRegistry.sol";
import "./ProviderOracleManager.sol";
import "./IOracleFallbackMechanism.sol";

/// @title For managing chainlink oracles for assets and submitting chainlink prices to the registry
/// @notice Once an oracle is added for an asset it can't be changed!
contract ChainlinkOracleManager is
    ProviderOracleManager,
    IOracleFallbackMechanism
{
    using SafeMath for uint256;

    event PriceRegistrySubmission(
        address asset,
        uint256 expiryTimestamp,
        uint256 price,
        uint256 expiryRoundId,
        address priceSubmitter,
        bool isFallback
    );

    struct BinarySearchResult {
        uint80 firstRound;
        uint80 lastRound;
        uint80 firstRoundProxy;
        uint80 lastRoundProxy;
    }

    uint256 public immutable fallbackPeriodSeconds;

    /// @param _config address of quant central configuration
    /// @param _fallbackPeriodSeconds amount of seconds before fallback price submitter can submit
    constructor(address _config, uint256 _fallbackPeriodSeconds)
        ProviderOracleManager(_config)
    {
        fallbackPeriodSeconds = _fallbackPeriodSeconds;
    }

    /// @notice Set the price of an asset at a timestamp using a chainlink round id
    /// @param _asset address of asset to set price for
    /// @param _expiryTimestamp expiry timestamp to set the price at
    /// @param _roundIdAfterExpiry the chainlink round id immediately after the expiry timestamp
    function setExpiryPriceInRegistryByRound(
        address _asset,
        uint256 _expiryTimestamp,
        uint256 _roundIdAfterExpiry
    ) external {
        _setExpiryPriceInRegistryByRound(
            _asset,
            _expiryTimestamp,
            _roundIdAfterExpiry
        );
    }

    /// @notice Get the expiry price from chainlink asset oracle and store it in the price registry
    /// @param _asset asset to set price of
    /// @param _expiryTimestamp timestamp of price
    /// @param _roundIdAfterExpiry the chainlink round id immediately after the option expired
    function _setExpiryPriceInRegistryByRound(
        address _asset,
        uint256 _expiryTimestamp,
        uint256 _roundIdAfterExpiry
    ) internal {
        address assetOracle = getAssetOracle(_asset);

        IEACAggregatorProxy aggregator = IEACAggregatorProxy(assetOracle);

        require(
            aggregator.getTimestamp(uint256(_roundIdAfterExpiry)) >
                _expiryTimestamp,
            "ChainlinkOracleManager: The round posted is not after the expiry timestamp"
        );

        uint16 phaseOffset = 64;
        uint16 phaseId = uint16(_roundIdAfterExpiry >> phaseOffset);

        uint64 expiryRound = uint64(_roundIdAfterExpiry) - 1;
        uint80 expiryRoundId =
            uint80((uint256(phaseId) << phaseOffset) | expiryRound);

        require(
            aggregator.getTimestamp(uint256(expiryRoundId)) <= _expiryTimestamp,
            "ChainlinkOracleManager: Expiry round prior to the one posted is after the expiry timestamp"
        );

        uint256 price = uint256(aggregator.getAnswer(expiryRoundId));

        emit PriceRegistrySubmission(
            _asset,
            _expiryTimestamp,
            price,
            expiryRoundId,
            msg.sender,
            false
        );

        PriceRegistry(config.priceRegistry()).setSettlementPrice(
            _asset,
            _expiryTimestamp,
            price
        );
    }

    /// @notice Searches for the correct price from chainlink and publishes it to the price registry
    /// @param _asset address of asset to set price for
    /// @param _expiryTimestamp expiry timestamp to set the price at
    function setExpiryPriceInRegistry(
        address _asset,
        uint256 _expiryTimestamp,
        bytes memory
    ) external override {
        //search and get round
        uint80 roundAfterExpiry = searchRoundToSubmit(_asset, _expiryTimestamp);

        //submit price to registry
        _setExpiryPriceInRegistryByRound(
            _asset,
            _expiryTimestamp,
            roundAfterExpiry
        );
    }

    /// @notice Searches for the round in the asset oracle immediately after the expiry timestamp
    /// @param _asset address of asset to search price for
    /// @param _expiryTimestamp expiry timestamp to find the price at or before
    /// @return the round id immediately after the timestamp submitted
    function searchRoundToSubmit(address _asset, uint256 _expiryTimestamp)
        public
        view
        returns (uint80)
    {
        address assetOracle = getAssetOracle(_asset);

        IEACAggregatorProxy aggregator = IEACAggregatorProxy(assetOracle);

        require(
            aggregator.latestTimestamp() > _expiryTimestamp,
            "ChainlinkOracleManager: The latest round timestamp is not after the expiry timestamp"
        );

        uint80 latestRound = uint80(aggregator.latestRound());

        uint16 phaseOffset = 64;
        uint16 phaseId = uint16(latestRound >> phaseOffset);

        uint80 lowestPossibleRound = uint80((phaseId << phaseOffset) | 1);
        uint80 highestPossibleRound = latestRound;
        uint80 firstId = lowestPossibleRound;
        uint80 lastId = highestPossibleRound;

        require(
            lastId > firstId,
            "ChainlinkOracleManager: Not enough rounds to find round after"
        );

        //binary search until we find two values our desired timestamp lies between
        while (lastId - firstId != 1) {
            BinarySearchResult memory result =
                _binarySearchStep(
                    aggregator,
                    _expiryTimestamp,
                    lowestPossibleRound,
                    highestPossibleRound
                );

            lowestPossibleRound = result.firstRound;
            highestPossibleRound = result.lastRound;
            firstId = result.firstRoundProxy;
            lastId = result.lastRoundProxy;
        }

        return highestPossibleRound; //return round above
    }

    /// @notice Performs a binary search step between the first and last round in the aggregator proxy
    /// @param _expiryTimestamp expiry timestamp to find the price at
    /// @param _firstRoundProxy the lowest possible round for the timestamp
    /// @param _lastRoundProxy the highest possible round for the timestamp
    /// @return a binary search result object representing lowest and highest possible rounds of the timestamp
    function _binarySearchStep(
        IEACAggregatorProxy aggregator,
        uint256 _expiryTimestamp,
        uint80 _firstRoundProxy,
        uint80 _lastRoundProxy
    ) internal view returns (BinarySearchResult memory) {
        uint16 phaseOffset = 64;
        uint16 phaseId = uint16(_lastRoundProxy >> phaseOffset);

        uint64 lastRoundId = uint64(_lastRoundProxy);
        uint64 firstRoundId = uint64(_firstRoundProxy);

        uint80 roundToCheck =
            _toUint80(uint256(firstRoundId).add(uint256(lastRoundId)).div(2));
        uint80 roundToCheckProxy =
            uint80((uint256(phaseId) << phaseOffset) | roundToCheck);

        uint256 roundToCheckTimestamp =
            aggregator.getTimestamp(uint256(roundToCheckProxy));

        if (roundToCheckTimestamp <= _expiryTimestamp) {
            return
                BinarySearchResult(
                    roundToCheckProxy,
                    _lastRoundProxy,
                    roundToCheck,
                    lastRoundId
                );
        }

        return
            BinarySearchResult(
                _firstRoundProxy,
                roundToCheckProxy,
                firstRoundId,
                roundToCheck
            );
    }

    /// @notice Get the current price of the asset from its oracle
    /// @param _asset asset to get price of
    /// @return current price of asset
    function getCurrentPrice(address _asset)
        external
        view
        override
        returns (uint256)
    {
        address assetOracle = getAssetOracle(_asset);
        IEACAggregatorProxy aggregator = IEACAggregatorProxy(assetOracle);
        int256 answer = aggregator.latestAnswer();
        require(
            answer > 0,
            "ChainlinkOracleManager: No pricing data available"
        );

        return uint256(answer);
    }

    /// @notice Fallback mechanism to submit price to the registry after the
    /// lock up period is passed with no successful submission
    /// @param _asset asset to set price of
    /// @param _expiryTimestamp timestamp of price
    /// @param _price price to submit
    function setExpiryPriceInRegistryFallback(
        address _asset,
        uint256 _expiryTimestamp,
        uint256 _price
    ) external override {
        require(
            config.hasRole(config.FALLBACK_PRICE_ROLE(), msg.sender),
            "ChainlinkOracleManager: Only the fallback price submitter can submit a fallback price"
        );

        require(
            block.timestamp >= _expiryTimestamp + fallbackPeriodSeconds,
            "ChainlinkOracleManager: The fallback price period has not passed since the timestamp"
        );

        emit PriceRegistrySubmission(
            _asset,
            _expiryTimestamp,
            _price,
            0,
            msg.sender,
            true
        );

        PriceRegistry(config.priceRegistry()).setSettlementPrice(
            _asset,
            _expiryTimestamp,
            _price
        );
    }

    /**
     * @dev Returns the downcasted uint80 from uint256, reverting on
     * overflow (when the input is greater than largest uint80).
     *
     * Counterpart to Solidity's `uint80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     */
    function _toUint80(uint256 _value) internal pure returns (uint80) {
        require(_value < 2**80, "SafeCast: value doesn't fit in 80 bits");
        return uint80(_value);
    }
}
