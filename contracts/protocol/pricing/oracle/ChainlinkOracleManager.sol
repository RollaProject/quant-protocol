// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../../../external/chainlink/AggregatorInterface.sol";
import "../PriceRegistry.sol";
import "./ProviderOracleManager.sol";
import "./IOracleFallbackMechanism.sol";

/// @title For managing chainlink oracles and which assets use them
/// @notice Once an oracle is added for an asset it can't be changed!
contract ChainlinkOracleManager is
    ProviderOracleManager,
    IOracleFallbackMechanism
{
    event ChainlinkPriceSubmission(
        address asset,
        uint256 expiryTimestamp,
        uint256 price,
        uint256 roundId,
        address oracle,
        bool isFallback
    );

    uint256 public FALLBACK_PERIOD_SECONDS = 7 * 86400; //todo; this should come from config

    /// @param _config address of quant central configuration
    // solhint-disable-next-line no-empty-blocks
    constructor(address _config) ProviderOracleManager(_config) {}

    /// @notice Get the expiry price from oracle and store it in the price registry so we have a copy
    /// @param _asset asset to set price of
    /// @param _expiryTimestamp timestamp of price
    /// @param _roundId the chainlink round id
    function setExpiryPriceInRegistry(
        address _asset,
        uint256 _expiryTimestamp,
        uint256 _roundId
    ) external override {
        //todo: we can potentially have a submitter role for each provider
        require(
            config.hasRole(config.PRICE_SUBMITTER_ROLE(), msg.sender),
            "ChainlinkOracleManager: Only the price submitter can submit a price"
        );
        AggregatorInterface aggregator =
            AggregatorInterface(assetOracles[_asset]);
        uint256 roundTimestamp = aggregator.getTimestamp(_roundId);
        require(
            _expiryTimestamp <= roundTimestamp,
            "ChainlinkOracleManager: RoundId is invalid"
        );

        //todo check the next roundId timestamp is bigger

        uint256 price = uint256(aggregator.getAnswer(_roundId));
        emit ChainlinkPriceSubmission(
            _asset,
            _expiryTimestamp,
            price,
            _roundId,
            assetOracles[_asset],
            false
        );
        PriceRegistry(config.priceRegistry()).setSettlementPrice(
            _asset,
            _expiryTimestamp,
            price
        );
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
        AggregatorInterface aggregator =
            AggregatorInterface(assetOracles[_asset]);
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
            "ChainlinkOracleManager: The fallback price period has not passed"
        );

        emit ChainlinkPriceSubmission(
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
}
