// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

interface IController {
    // TODO: Add mappings to interfaces

    function mintOptionsPosition(
        address _to,
        address _qToken,
        uint256 _optionsAmount
    ) external;

    function mintSpread(
        address _qTokenToMint,
        address _qTokenForCollateral,
        uint256 _optionsAmount
    ) external;

    function exercise(address _qToken, uint256 _amount) external;

    function claimCollateral(uint256 _collateralTokenId, uint256 _amount)
        external;

    function neutralizePosition(uint256 _collateralTokenId, uint256 _amount)
        external;

    function getCollateralRequirement(
        address _qTokenToMint,
        address _qTokenForCollateral,
        uint256 _optionsAmount
    ) external view returns (address collateral, uint256 collateralAmount);

    function getPayout(address _qToken, uint256 _amount)
        external
        view
        returns (
            bool isSettled,
            address payoutToken,
            uint256 payoutAmount
        );
}
