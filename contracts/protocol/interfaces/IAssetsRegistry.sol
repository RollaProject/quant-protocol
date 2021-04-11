// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

interface IAssetsRegistry {
    function addAsset(
        address _underlying,
        string calldata _name,
        string calldata _symbol,
        uint8 _decimals
    ) external;
}
