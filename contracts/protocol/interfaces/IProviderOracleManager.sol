// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

interface IProviderOracleManager {
    function addAssetOracle(address _asset, address _oracle) external;

    function getAssetOracle(address _asset) external view returns (address);

    function setExpiryPriceInRegistry(
        address _asset,
        uint256 _expiryTimestamp,
        bytes memory _calldata
    ) external;

    function getAssetsLength() external view returns (uint256);

    function getCurrentPrice(address _asset)
    external
    view
    returns (uint256);
}
