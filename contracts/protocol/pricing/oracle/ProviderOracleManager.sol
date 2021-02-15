// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../../QuantConfig.sol";

/// @title Oracle manager for holding asset addresses and their oracle addresses for a single provider
/// @notice Once an oracle is added for an asset it can't be changed!
abstract contract ProviderOracleManager {
    /// @notice quant central configuration
    QuantConfig public config;

    /// @notice asset address => oracle address
    mapping(address => address) public assetOracles;

    /// @notice exhaustive list of asset addresses in map
    address[] public assets;

    constructor(address _config) {
        config = QuantConfig(_config);
    }

    /// @notice Add an asset to the oracle manager with its corresponding oracle address
    /// @dev Once this is set for an asset, it can't be changed or removed
    /// @param _asset the address of the asset token we are adding the oracle for
    /// @param _oracle the address of the oracle
    function addAssetOracle(address _asset, address _oracle) external {
        require(
            config.hasRole(config.ORACLE_MANAGER_ROLE(), msg.sender),
            "OracleManager: Only an oracle admin can add an oracle"
        );
        require(
            assetOracles[_asset] == address(0),
            "OracleManager: Oracle already set for asset"
        );
        assets.push(_asset);
        assetOracles[_asset] = _oracle;
    }

    /// @notice Get the total number of assets managed by the oracle manager
    /// @return total number of assets managed by the oracle manager
    function getAssetsLength() external view returns (uint256) {
        return assets.length;
    }

    //todo we need to change the round id parameter to a generic param as roundid is exclusive to chainlink
    /// @notice Get the expiry price from oracle and store it in the price registry so we have a copy
    /// @param _asset asset to set price of
    /// @param _expiryTimestamp timestamp of price
    /// @param _roundId the chainlink round id
    function setExpiryPriceInRegistry(
        address _asset,
        uint256 _expiryTimestamp,
        uint256 _roundId
    ) external virtual;

    /// @notice Function that should be overridden which should return the current price of an asset from the provider
    /// @param _asset the address of the asset token we want the price for
    /// @return the current price of the asset
    function getCurrentPrice(address _asset)
        external
        view
        virtual
        returns (uint256);
}
