// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

interface IAssetsRegistry {
    event AssetAdded(
        address indexed underlying,
        string name,
        string symbol,
        uint8 decimals,
        uint256 quantityTickSize
    );

    function addAsset(
        address _underlying,
        string calldata _name,
        string calldata _symbol,
        uint8 _decimals,
        uint256 _quantityTickSize
    ) external;

    function assetProperties(address)
        external
        view
        returns (
            string memory,
            string memory,
            uint8,
            uint256
        );
}
