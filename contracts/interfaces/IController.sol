// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../libraries/Actions.sol";

interface IController {
    event OptionsPositionMinted(
        address indexed mintedTo,
        address indexed minter,
        address indexed qToken,
        uint256 optionsAmount,
        address collateralAsset,
        uint256 collateralAmount
    );

    event SpreadMinted(
        address indexed account,
        address indexed qTokenToMint,
        address indexed qTokenForCollateral,
        uint256 optionsAmount,
        address collateralAsset,
        uint256 collateralAmount
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

    function operate(ActionArgs[] memory) external returns (bool);

    function initialize(
        string memory,
        string memory,
        address,
        address
    ) external;

    function optionsFactory() external view returns (address);

    function operateProxy() external view returns (address);

    function quantCalculator() external view returns (address);
}
