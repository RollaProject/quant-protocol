// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../libraries/Actions.sol";

interface IController {
    /// @notice emitted after a new position is created
    /// @param mintedTo address that received both QTokens and CollateralTokens
    /// @param minter address that provided collateral and created the position
    /// @param qToken address of the QToken minted
    /// @param optionsAmount amount of options minted
    /// @param collateralAsset asset provided as collateral to create the position
    /// @param collateralAmount amount of collateral provided
    event OptionsPositionMinted(
        address indexed mintedTo,
        address indexed minter,
        address indexed qToken,
        uint256 optionsAmount,
        address collateralAsset,
        uint256 collateralAmount
    );

    /// @notice emitted after a spread position is created
    /// @param account address that created the spread position, receiving both QTokens and CollateralTokens
    /// @param qTokenToMint QToken of the option the position is going long on
    /// @param qTokenForCollateral QToken of the option the position is shorting
    /// @param optionsAmount amount of qTokenToMint options minted
    /// @param collateralAsset asset provided as collateral to create the position (if debit spread)
    /// @param collateralAmount amount of collateral provided (if debit spread)
    event SpreadMinted(
        address indexed account,
        address indexed qTokenToMint,
        address indexed qTokenForCollateral,
        uint256 optionsAmount,
        address collateralAsset,
        uint256 collateralAmount
    );

    /// @notice emitted after a QToken is used to close a long position after expiry
    /// @param account address that used the QToken to exercise the position
    /// @param qToken address of the QToken representing the long position
    /// @param amountExercised amount of options exercised
    /// @param payout amount received from exercising the options
    /// @param payoutAsset asset received after exercising the options
    event OptionsExercised(
        address indexed account,
        address indexed qToken,
        uint256 amountExercised,
        uint256 payout,
        address payoutAsset
    );

    /// @notice emitted after both QTokens and CollateralTokens are used to claim the initial collateral
    /// that was used to create the position
    /// @param account address that used the QTokens and CollateralTokens to claim the collateral
    /// @param qToken address of the QToken representing the long position
    /// @param amountNeutralized amount of options that were used to claim the collateral
    /// @param collateralReclaimed amount of collateral returned
    /// @param collateralAsset asset returned after claiming the collateral
    /// @param longTokenReturned QToken returned if neutralizing a spread position
    event NeutralizePosition(
        address indexed account,
        address qToken,
        uint256 amountNeutralized,
        uint256 collateralReclaimed,
        address collateralAsset,
        address longTokenReturned
    );

    /// @notice emitted after a CollateralToken is used to close a short position after expiry
    /// @param account address that used the CollateralToken to close the position
    /// @param collateralTokenId ERC1155 id of the CollateralToken representing the short position
    /// @param amountClaimed amount of CollateralToken used to close the position
    /// @param collateralReturned amount returned of the asset used to mint the option
    /// @param collateralAsset asset returned after claiming the collateral, i.e. the same used when minting the option
    event CollateralClaimed(
        address indexed account,
        uint256 indexed collateralTokenId,
        uint256 amountClaimed,
        uint256 collateralReturned,
        address collateralAsset
    );

    /// @notice The main entry point in the Quant Protocol. This function takes an array of actions
    /// and executes them in order. Actions are passed encoded as ActionArgs structs, and then for each
    /// different action, the relevant arguments are parsed and passed to the respective internal function
    /// WARNING: DO NOT UNDER ANY CIRCUMSTANCES APPROVE THE OperateProxy TO SPEND YOUR FUNDS (using
    /// CALL action) OR ANYONE WILL BE ABLE TO SPEND THEM AFTER YOU!!!
    /// @dev For documentation of each individual action, see the corresponding internal function in Controller.sol
    /// @param _actions array of ActionArgs structs, each representing an action to be executed
    function operate(ActionArgs[] memory _actions) external;

    /// @notice Mints options for a given QToken, which must have been previously created in
    /// the configured OptionsFactory.
    /// @dev The caller (or signer in case of meta transactions) must first approve the Controller
    /// to spend the collateral asset, and then this function can be called, pulling the collateral
    /// from the caller/signer and minting QTokens and CollateralTokens to the given `to` address.
    /// Note that QTokens represent a long position, giving holders the ability to exercise options
    /// after expiry, while CollateralTokens represent a short position, giving holders the ability
    /// to claim the collateral after expiry.
    /// @param _to The address to which the QTokens and CollateralTokens will be minted.
    /// @param _qToken The QToken that represents the long position for the option to be minted.
    /// @param _amount The amount of options to be minted.
    function mintOptionsPosition(address _to, address _qToken, uint256 _amount)
        external;

    /// @notice Creates a spread position from an option to long and another option to short.
    /// @dev The caller (or signer in case of meta transactions) must first approve the Controller
    /// to spend the collateral asset in cases of a debit spread.
    /// @param _qTokenToMint The QToken for the option to be long.
    /// @param _qTokenForCollateral The QToken for the option to be short.
    /// @param _amount The amount of long options to be minted.
    function mintSpread(
        address _qTokenToMint,
        address _qTokenForCollateral,
        uint256 _amount
    )
        external;

    /// @notice Closes a long position after the option's expiry.
    /// @dev Pass an `_amount` of 0 to close the entire position.
    /// @param _qToken The QToken representing the long position to be closed.
    /// @param _amount The amount of options to exercise.
    function exercise(address _qToken, uint256 _amount) external;

    /// @notice Closes a short position after the option's expiry.
    /// @param _collateralTokenId ERC1155 token id representing the short position to be closed.
    /// @param _amount The size of the position to close.
    function claimCollateral(uint256 _collateralTokenId, uint256 _amount)
        external;

    /// @notice Closes a neutral position, claiming all the collateral required to create it.
    /// @dev Unlike `_exercise` and `_claimCollateral`, this function does not require the option to be expired.
    /// @param _collateralTokenId ERC1155 token id representing the position to be closed.
    /// @param _amount The size of the position to close.
    function neutralizePosition(uint256 _collateralTokenId, uint256 _amount)
        external;
}