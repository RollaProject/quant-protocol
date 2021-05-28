// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/IProtocolFeeCollector.sol";

/// @title Protocol fee collector
/// @author Quant Finance
/// @notice Collects fees and distributes to relevant parties
contract ProtocolFeeCollector is IProtocolFeeCollector {
    using SafeMath for uint256;
    using Address for address;
    using SafeERC20 for IERC20;

    /// @inheritdoc IProtocolFeeCollector
    function distributeFees(
        uint256 _totalFee,
        address _feeToken,
        address _channelFeeCollector,
        address _referrer
    ) external override returns (uint256) {
        if (_channelFeeCollector != address(0)) {
            uint256 channelFee = _totalFee.mul(4000).div(10000);

            IERC20(_feeToken).safeTransfer(_channelFeeCollector, channelFee);

            if (_channelFeeCollector.isContract()) {
                //call distribute fees
            }
        }

        //send remaining funds to protocol treasury
        IERC20(_feeToken).safeTransfer(
            address(0), //protocolTreasury
            IERC20(_feeToken).balanceOf(address(this))
        );
    }
}
