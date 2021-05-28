// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../options/QToken.sol";

/// @title Protocol fee collector
/// @author Quant Finance
/// @notice Used to collect fees during protocol actions
interface IProtocolFeeCollector {
    /// @notice Distribute the fees to relevant parties
    function distributeFees(
        uint256 _totalFee,
        address _feeToken,
        address _channelFeeCollector,
        address _referrer
    ) external returns (uint256);
}
