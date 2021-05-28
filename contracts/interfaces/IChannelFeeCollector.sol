// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../options/QToken.sol";

/// @title Protocol fee collector
/// @author Quant Finance
/// @notice Used to distribute fees for a particular channel
interface IChannelFeeCollector {
    /// @notice Distribute the fees to relevant parties
    /// @param _channelFee total fee which is owed to the channel
    /// @param _referrer address of referrer for the channel
    function distributeChannelFees(
        uint256 _channelFee,
        address _referrer
    ) external;
}