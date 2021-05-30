// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

interface IQuantCalculator {
    function calculateClaimableCollateral(
        uint256,
        uint256,
        address,
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
        address,
        uint256
    ) external view returns (address, uint256);

    function getExercisePayout(
        address,
        address,
        uint256
    )
        external
        view
        returns (
            bool,
            address,
            uint256
        );

    function getNeutralizationPayout(
        address _qTokenLong,
        address _qTokenShort,
        uint256 _amountToNeutralize,
        address _optionsFactory
    ) external view returns (address collateralType, uint256 collateralOwed);

    // solhint-disable-next-line func-name-mixedcase
    function OPTIONS_DECIMALS() external view returns (uint8);
}
