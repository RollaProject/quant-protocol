// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IQuantCalculator {
    function calculateClaimableCollateral(
        uint256,
        uint256,
        address
    )
        external
        view
        returns (
            uint256,
            address,
            uint256
        );

    function getCollateralRequirement(
        address,
        address,
        uint256
    ) external view returns (address, uint256);

    function getExercisePayout(address, uint256)
        external
        view
        returns (
            bool,
            address,
            uint256
        );

    function getNeutralizationPayout(
        address _qTokenShort,
        address _qTokenLong,
        uint256 _amountToNeutralize
    ) external view returns (address collateralType, uint256 collateralOwed);

    // solhint-disable-next-line func-name-mixedcase
    function OPTIONS_DECIMALS() external view returns (uint8);

    function strikeAssetDecimals() external view returns (uint8);

    function optionsFactory() external view returns (address);
}
