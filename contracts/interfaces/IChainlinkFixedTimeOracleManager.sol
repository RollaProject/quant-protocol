// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.0;

import "./IChainlinkOracleManager.sol";

interface IChainlinkFixedTimeOracleManager is IChainlinkOracleManager {
    event FixedTimeUpdate(uint256 fixedTime, bool isValidTime);

    function setFixedTimeUpdate(uint256 fixedTime, bool isValidTime) external;

    /// @notice fixed time => is allowed
    function chainlinkFixedTimeUpdates(uint256) external view returns (bool);
}
