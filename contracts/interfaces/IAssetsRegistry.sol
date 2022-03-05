// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IAssetsRegistry {
    event AssetAdded(
        address indexed underlying,
        string name,
        string symbol,
        uint8 decimals
    );

    function addAsset(
        address,
        string calldata,
        string calldata,
        uint8
    ) external;

    function addAssetWithOptionalERC20Methods(address) external;

    function assetProperties(address)
        external
        view
        returns (
            string memory,
            string memory,
            uint8
        );

    function registeredAssets(uint256) external view returns (address);

    function getAssetsLength() external view returns (uint256);
}
