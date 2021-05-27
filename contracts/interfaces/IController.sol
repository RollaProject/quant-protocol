// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "./IOptionsFactory.sol";

interface IController {
    event OptionsPositionMinted(
        address indexed mintedTo,
        address indexed minter,
        address indexed qToken,
        uint256 optionsAmount
    );

    event SpreadMinted(
        address indexed account,
        address indexed qTokenToMint,
        address indexed qTokenForCollateral,
        uint256 optionsAmount
    );

    event OptionsExercised(
        address indexed account,
        address indexed qToken,
        uint256 amountExercised,
        uint256 payout,
        address payoutAsset
    );

    event NeutralizePosition(
        address indexed account,
        address qToken,
        uint256 amountNeutralized,
        uint256 collateralReclaimed,
        address collateralAsset,
        address longTokenReturned
    );

    event CollateralClaimed(
        address indexed account,
        uint256 indexed collateralTokenId,
        uint256 amountClaimed,
        uint256 collateralReturned,
        address collateralAsset
    );

    function mintOptionsPosition(
        address _to,
        address _qToken,
        uint256 _optionsAmount
    ) external returns (uint256);

    function mintSpread(
        address _qTokenToMint,
        address _qTokenForCollateral,
        uint256 _optionsAmount
    ) external returns (uint256);

    function exercise(address _qToken, uint256 _amount) external;

    function claimCollateral(uint256 _collateralTokenId, uint256 _amount)
        external;

    function neutralizePosition(uint256 _collateralTokenId, uint256 _amount)
        external;

    function initialize(
        string memory,
        string memory,
        address
    ) external;

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

    function optionsFactory() external view returns (IOptionsFactory);

    // solhint-disable-next-line func-name-mixedcase
    function OPTIONS_DECIMALS() external view returns (uint8);
}
