// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./IChainlinkOracleManager.sol";

interface IChainlinkFixedTimeOracleManager is IChainlinkOracleManager {
    /// @notice emitted when a new time is added for fixed updates
    event FixedTimeUpdate(uint24 fixedTime, bool isValidTime);

    /// @notice Validate or invalidated a given fixed time for updates
    function setFixedTimeUpdate(uint24 fixedTime, bool isValidTime) external;

    /// @notice fixed time => is allowed
    function chainlinkFixedTimeUpdates(uint24) external view returns (bool);
}
