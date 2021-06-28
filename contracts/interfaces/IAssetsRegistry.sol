// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

interface IAssetsRegistry {
    event AssetAdded(
        address indexed underlying,
        string name,
        string symbol,
        uint8 decimals,
        uint256 quantityTickSize
    );

    event QuantityTickSizeUpdated(
        address indexed underlying,
        uint256 previousQuantityTickSize,
        uint256 newQuantityTickSize
    );

    function addAsset(
        address,
        string calldata,
        string calldata,
        uint8,
        uint256
    ) external;

    function setQuantityTickSize(address, uint256) external;

    function assetProperties(address)
        external
        view
        returns (
            string memory,
            string memory,
            uint8,
            uint256
        );

    function registeredAssets(uint256) external view returns (address);

    function getAssetsLength() external view returns (uint256);
}
