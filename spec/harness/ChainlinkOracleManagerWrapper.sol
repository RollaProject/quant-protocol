// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "../../contracts/pricing/oracle/ChainlinkOracleManager.sol";
import "../../contracts/interfaces/external/chainlink/IEACAggregatorProxy.sol";


contract ChainlinkOracleManagerWrapper is ChainlinkOracleManager {

    address aggregatorAddress;

    ////////////////////////////////////////////////////////////////////////////
    //                         Constructors and inits                         //
    ////////////////////////////////////////////////////////////////////////////
    constructor(
        address _config,
        uint8 _strikeAssetDecimals,
        uint256 _fallbackPeriodSeconds
    ) ChainlinkOracleManager(_config, _strikeAssetDecimals, _fallbackPeriodSeconds) {

    }

    ////////////////////////////////////////////////////////////////////////////
    //                        Getters for The Internals                       //
    ////////////////////////////////////////////////////////////////////////////

    function getAssetOracle(address _asset)
        public
        view
        override
        virtual
        returns (address)
    {
        address assetOracle = assetOracles[_asset];
        // Assuming that this require is true
        // require(
        //     assetOracles[_asset] != address(0),
        //     "ProviderOracleManager: Oracle doesn't exist for that asset"
        // );
        return assetOracle;
    }
    
    ////////////////////////////////////////////////////////////////////////////
    //                       Each operation wrapper                           //
    ////////////////////////////////////////////////////////////////////////////
    function getExpiryPrice(
        IEACAggregatorProxy _aggregator,
        uint256 _expiryTimestamp,
        uint256 _roundIdAfterExpiry,
        uint256 _expiryRoundId
    ) public view returns (uint256 expiryPrice, uint256 expiryRoundId) {
        return _getExpiryPrice(
            _aggregator,
            _expiryTimestamp,
            _roundIdAfterExpiry,
            _expiryRoundId
        );
    }

    function getAggregator(address assetOracle) public view returns (address) {
        return aggregatorAddress;
    }
}