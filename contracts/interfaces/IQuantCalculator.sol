// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IQuantCalculator {
    function calculateClaimableCollateral(
        uint256 _collateralTokenId,
        uint256 _amount,
        address _msgSender
    )
        external
        view
        returns (
            uint256 returnableCollateral,
            address collateralAsset,
            uint256 amountToClaim
        );

    function getCollateralRequirement(
        address _qTokenToMint,
        address _qTokenForCollateral,
        uint256 _amount
    ) external view returns (address collateral, uint256 collateralAmount);

    function getExercisePayout(address _qToken, uint256 _amount)
        external
        view
        returns (
            bool isSettled,
            address payoutToken,
            uint256 payoutAmount
        );

    function getNeutralizationPayout(
        address _qTokenShort,
        address _qTokenLong,
        uint256 _amountToNeutralize
    ) external view returns (address collateralType, uint256 collateralOwed);

    /// @notice The amount of decimals for Quant options
    // solhint-disable-next-line func-name-mixedcase
    function OPTIONS_DECIMALS() external view returns (uint8);

    /// @notice The amount of decimals for the strike asset used in the Quant Protocol
    function strikeAssetDecimals() external view returns (uint8);

    /// @notice The address of the factory contract that creates Quant options
    function optionsFactory() external view returns (address);
}
