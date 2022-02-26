// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "../../contracts/pricing/oracle/ChainlinkOracleManager.sol";
import "../../contracts/interfaces/external/chainlink/IEACAggregatorProxy.sol";


contract ChainlinkOracleManagerWrapper is ChainlinkOracleManager {
    ////////////////////////////////////////////////////////////////////////////
    //                         Constructors and inits                         //
    ////////////////////////////////////////////////////////////////////////////
    //constructor( ) .. public { }

    ////////////////////////////////////////////////////////////////////////////
    //                        Getters for The Internals                       //
    ////////////////////////////////////////////////////////////////////////////

    function getLatestTimestampOfAsset(address _asset, address u)
        public
        view
        returns (uint256)
    {
        address assetOracle = getAssetOracle(_asset);
        IEACAggregatorProxy aggregator = IEACAggregatorProxy(assetOracle);
    }

    function getLatestRoundOfAsset(
        address to,
        address qToken,
        uint256 amount
    ) public {
       address assetOracle = getAssetOracle(_asset);
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

    function getAssetOracle(address _asset)
        public
        view
        override
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
}