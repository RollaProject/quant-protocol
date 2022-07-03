// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

import "./ChainlinkOracleManager.sol";
import "../../interfaces/external/chainlink/IEACAggregatorProxy.sol";
import "../../interfaces/IChainlinkFixedTimeOracleManager.sol";

/// @title For managing Chainlink oracles with updates at fixed times.
/// @author Rolla
/// @notice Update times are counted as seconds since the start of the day.
contract ChainlinkFixedTimeOracleManager is
    ChainlinkOracleManager,
    IChainlinkFixedTimeOracleManager
{
    mapping(uint24 => bool) public override chainlinkFixedTimeUpdates;

    /// @param _fallbackPeriodSeconds amount of seconds before fallback price submitter can submit
    constructor(
        address _priceRegistry,
        uint8 _strikeAssetDecimals,
        uint88 _fallbackPeriodSeconds
    )
        ChainlinkOracleManager(
            _priceRegistry,
            _strikeAssetDecimals,
            _fallbackPeriodSeconds
        )
    // solhint-disable-next-line no-empty-blocks
    {}

    /// @inheritdoc IChainlinkFixedTimeOracleManager
    function setFixedTimeUpdate(uint24 fixedTime, bool isValidTime)
        external
        override
        onlyOwner
    {
        chainlinkFixedTimeUpdates[fixedTime] = isValidTime;

        emit FixedTimeUpdate(fixedTime, isValidTime);
    }

    /// @inheritdoc IProviderOracleManager
    function isValidOption(
        address _underlyingAsset,
        uint88 _expiryTime,
        uint256
    )
        external
        view
        override (ChainlinkOracleManager, IProviderOracleManager)
        returns (bool)
    {
        uint24 timeInSeconds = uint24(_expiryTime % 86400);
        return assetOracles[_underlyingAsset]
            != address(0)
            && chainlinkFixedTimeUpdates[timeInSeconds];
    }

    /// @notice Gets the price and roundId for a given expiry time.
    /// @param aggregator address of the Chainlink aggregator proxy contract
    /// @param _expiryTimestamp option expiration timestamp in seconds since the Unix epoch
    /// @param _roundIdAfterExpiry id of the round right after the expiry
    /// @param _expiryRoundId id of the round right before or at the expiry
    /// @return price for the expiry time
    /// @return roundId for the expiry time
    function _getExpiryPrice(
        IEACAggregatorProxy aggregator,
        uint88 _expiryTimestamp,
        uint256 _roundIdAfterExpiry,
        uint256 _expiryRoundId
    )
        internal
        view
        override
        returns (uint256, uint256)
    {
        int256 price;
        uint256 roundId;

        if (
            aggregator.getTimestamp(uint256(_expiryRoundId)) == _expiryTimestamp
        ) {
            (, price,,,) = aggregator.getRoundData(uint80(_expiryRoundId));
            roundId = _expiryRoundId;
        } else {
            (, price,,,) = aggregator.getRoundData(uint80(_roundIdAfterExpiry));
            roundId = _roundIdAfterExpiry;
        }

        return (uint256(price), roundId);
    }
}
