// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../interfaces/IProtocolFeeCollector.sol";

/// @title Mock protocol fee collector
/// @author Quant Finance
/// @notice Collects fees but doesnt distribute them
contract MockProtocolFeeCollector is IProtocolFeeCollector {
    /// @inheritdoc IProtocolFeeCollector
    function distributeFees(
        uint256 _totalFee,
        address _feeToken,
        address _channelFeeCollector,
        address _referrer
    ) external view override returns (uint256) {
        //noop: doesn't distribute
    }
}
