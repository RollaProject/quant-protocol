// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../../../external/chainlink/IEACAggregatorProxy.sol";
import "../PriceRegistry.sol";
import "./ProviderOracleManager.sol";
import "./IOracleFallbackMechanism.sol";

/// @title For managing chainlink oracles and which assets use them
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
        address oracle,
        bool isFallback
    );

    struct BinarySearchResult {
        uint80 firstRound;
        uint80 lastRound;
        uint80 firstRoundProxy;
        uint80 lastRoundProxy;
    }

    uint256 public immutable FALLBACK_PERIOD_SECONDS;

    /// @param _config address of quant central configuration
    /// @param _fallbackPeriodSeconds amount of seconds before fallback price submitter can submit
    constructor(
        address _config,
        uint256 _fallbackPeriodSeconds
    ) ProviderOracleManager(_config) {
        FALLBACK_PERIOD_SECONDS = _fallbackPeriodSeconds;
    }

    function setExpiryPriceInRegistryByRound(
        address _asset,
        uint256 _expiryTimestamp,
        uint256 _roundIdAfterExpiry
    ) external {
        _setExpiryPriceInRegistryByRound(_asset, _expiryTimestamp, _roundIdAfterExpiry);
    }

    /// @notice Get the expiry price from oracle and store it in the price registry so we have a copy
    /// @param _asset asset to set price of
    /// @param _expiryTimestamp timestamp of price
    /// @param _roundIdAfterExpiry the chainlink round id immediately after the option expired
    function _setExpiryPriceInRegistryByRound(
        address _asset,
        uint256 _expiryTimestamp,
        uint256 _roundIdAfterExpiry
    ) internal {
        IEACAggregatorProxy aggregator = IEACAggregatorProxy(assetOracles[_asset]);

        require(
            aggregator.getTimestamp(uint256(_roundIdAfterExpiry)) > _expiryTimestamp,
            "ChainlinkOracleManager: The round after is not after the expiry timestamp"
        );

        uint16 phaseOffset = 64;
        uint16 phaseId = uint16(_roundIdAfterExpiry >> phaseOffset);

        uint64 expiryRound = uint64(_roundIdAfterExpiry) - 1;
        uint80 expiryRoundId = uint80((uint256(phaseId) << phaseOffset) | expiryRound);

        require(
            aggregator.getTimestamp(uint256(expiryRoundId)) <= _expiryTimestamp,
            "ChainlinkOracleManager: The expiry round is not before or equal to the expiry timestamp"
        );

        uint256 price = uint256(aggregator.getAnswer(expiryRoundId));

        emit PriceRegistrySubmission(
            _asset,
            _expiryTimestamp,
            price,
            expiryRoundId,
            assetOracles[_asset],
            false
        );

        PriceRegistry(config.priceRegistry()).setSettlementPrice(
            _asset,
            _expiryTimestamp,
            price
        );
    }

    function setExpiryPriceInRegistry(
        address _asset,
        uint256 _expiryTimestamp,
        bytes32 _calldata
    ) external override {
        uint8 maxIterations = 50;

        IEACAggregatorProxy aggregator = IEACAggregatorProxy(assetOracles[_asset]);

        (uint80 latestRound,,,,) = aggregator.latestRoundData();

        //search and get round
        uint80 roundAfterExpiry = searchRoundToSubmit(_asset, _expiryTimestamp, latestRound, maxIterations);

        //submit price to registry
        _setExpiryPriceInRegistryByRound(_asset, _expiryTimestamp, roundAfterExpiry);
    }

    function searchRoundToSubmit(
        address _asset,
        uint256 _expiryTimestamp,
        uint80 _latestRound,
        uint8 _maxIterations
    ) public view returns(uint80) {
        IEACAggregatorProxy aggregator = IEACAggregatorProxy(assetOracles[_asset]);

        require(
            aggregator.latestTimestamp() > _expiryTimestamp,
            "ChainlinkOracleManager: The latest round timestamp is not after the expiry timestamp"
        );

        uint16 phaseOffset = 64;
        uint16 phaseId = uint16(_latestRound >> phaseOffset);

        uint80 lowestPossibleRound = uint80((phaseId << phaseOffset) | 1);
        uint80 highestPossibleRound = _latestRound;
        uint80 firstId = 0;
        uint80 lastId = 0;

        //binary search until we find two values our desired timestamp lies between
        for (uint8 i = 0; i < _maxIterations; i++) {
            BinarySearchResult memory result = _binarySearchStep(
                aggregator,
                _expiryTimestamp,
                lowestPossibleRound,
                highestPossibleRound
            );

            lowestPossibleRound = result.firstRound;
            highestPossibleRound = result.lastRound;
            firstId = result.firstRoundProxy;
            lastId = result.lastRoundProxy;

            if((lastId - firstId) == 1) {
                break; //terminate loop as the rounds are adjacent
            }
        }

        return highestPossibleRound; //return round above
    }

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

        uint80 roundToCheck = _toUint80(uint256(firstRoundId).add(uint256(lastRoundId)).div(2));
        uint80 roundToCheckProxy = uint80((uint256(phaseId) << phaseOffset) | roundToCheck);

        uint256 firstRoundTimestamp = aggregator.getTimestamp(uint256(_firstRoundProxy));
        uint256 roundToCheckTimestamp = aggregator.getTimestamp(uint256(roundToCheckProxy));
        uint256 lastRoundTimestamp = aggregator.getTimestamp(uint256(_lastRoundProxy));

        if(roundToCheckTimestamp <= _expiryTimestamp) {
            return BinarySearchResult(roundToCheckProxy, _lastRoundProxy, roundToCheck, lastRoundId);
        }

        return BinarySearchResult(_firstRoundProxy, roundToCheckProxy, firstRoundId, roundToCheck);
    }

    /// @notice Get the expiry price from oracle and store it in the price registry so we have a copy
    /// @param _asset asset to get price of
    function getCurrentPrice(address _asset)
        external
        view
        override
        returns (uint256)
    {
        require(
            assetOracles[_asset] != address(0),
            "ChainlinkOracleManager: Asset not supported"
        );
        IEACAggregatorProxy aggregator = IEACAggregatorProxy(assetOracles[_asset]);
        int256 answer = aggregator.latestAnswer();
        require(
            answer > 0,
            "ChainlinkOracleManager: No pricing data available"
        );

        return uint256(answer);
    }

    /// @notice Fallback mechanism to submit price to the registry after the lock up period is passed with no successful submission
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
            block.timestamp >= _expiryTimestamp + FALLBACK_PERIOD_SECONDS,
            "ChainlinkOracleManager: The fallback price period has not passed since the timestamp"
        );

        emit PriceRegistrySubmission(
            _asset,
            _expiryTimestamp,
            _price,
            0,
            assetOracles[_asset],
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
        require(_value < 2**80, "SafeCast: value doesn\'t fit in 80 bits");
        return uint80(_value);
    }
}
