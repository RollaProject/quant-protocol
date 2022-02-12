// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;

import "./ChainlinkOracleManager.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../interfaces/external/chainlink/IEACAggregatorProxy.sol";
import "../../interfaces/IChainlinkFixedTimeOracleManager.sol";

contract ChainlinkFixedTimeOracleManager is ChainlinkOracleManager, IChainlinkFixedTimeOracleManager {
    using SafeMath for uint256;

    mapping(uint256 => bool) public override chainlinkFixedTimeUpdates;

    /// @param _config address of quant central configuration
    /// @param _fallbackPeriodSeconds amount of seconds before fallback price submitter can submit
    constructor(
        address _config,
        uint8 _strikeAssetDecimals,
        uint256 _fallbackPeriodSeconds
    )
        ChainlinkOracleManager(
            _config,
            _strikeAssetDecimals,
            _fallbackPeriodSeconds
        )
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function setFixedTimeUpdate(uint256 fixedTime, bool isValidTime) external override {
        require(
            config.hasRole(
                config.quantRoles("ORACLE_MANAGER_ROLE"),
                msg.sender
            ),
            "ChainlinkFixedTimeOracleManager: Only an oracle admin can add a fixed time for updates"
        );

        chainlinkFixedTimeUpdates[fixedTime] = isValidTime;

        emit FixedTimeUpdate(
            fixedTime,
            isValidTime
        );
    }

    function isValidOption(
        address,
        uint256 _expiryTime,
        uint256
    ) public view override(ChainlinkOracleManager, IProviderOracleManager) returns (bool) {
        uint256 timeInSeconds = _expiryTime.mod(86400);
        return chainlinkFixedTimeUpdates[timeInSeconds];
    }

    function _getExpiryPrice(
        IEACAggregatorProxy aggregator,
        uint256 _expiryTimestamp,
        uint256 _roundIdAfterExpiry,
        uint256 _expiryRoundId
    ) internal view override returns (uint256 price, uint256 roundId) {
        if (
            aggregator.getTimestamp(uint256(_expiryRoundId)) == _expiryTimestamp
        ) {
            price = uint256(aggregator.getAnswer(_expiryRoundId));
            roundId = _expiryRoundId;
        } else {
            price = uint256(aggregator.getAnswer(_roundIdAfterExpiry));
            roundId = _roundIdAfterExpiry;
        }
    }
}
