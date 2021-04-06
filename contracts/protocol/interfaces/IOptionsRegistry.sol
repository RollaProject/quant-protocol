// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

interface IOptionsRegistry {
    struct OptionDetails {
        // address of qToken
        address qToken;
        // whether or not the option is shown in the frontend
        bool isVisible;
    }

    function addOption(address _qToken) external;

    function makeOptionVisible(address _qToken, uint256 index) external;

    function makeOptionInvisible(address _qToken, uint256 index) external;

    function getOptionDetails(address _underlyingAsset, uint256 _index)
        external
        view
        returns (OptionDetails memory);

    function numberOfUnderlyingAssets() external view returns (uint256);

    function numberOfOptionsForUnderlying(address _underlying)
        external
        view
        returns (uint256);
}
