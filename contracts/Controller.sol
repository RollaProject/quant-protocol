// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "./interfaces/IController.sol";
import "./utils/EIP712MetaTransaction.sol";
import {SafeTransferLib, ERC20 as IERC20} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import "./libraries/Actions.sol";
import "./options/OptionsFactory.sol";
import "./utils/OperateProxy.sol";
import "./QuantCalculator.sol";
import "./pricing/OracleRegistry.sol";
import "./options/CollateralToken.sol";
import "./options/QToken.sol";

/// @title The main entry point in the Quant Protocol
/// @author Rolla
/// @notice Handles minting options and spreads, exercising, claiming collateral and neutralizing positions.
/// @dev This contract has no receive method, and also no way to recover tokens sent to it by accident.
/// Its balance of options or any other tokens are never used in any calculations, so there is no risk if that happens.
/// @dev This contract is an upgradeable proxy, and it supports meta transactions.
/// @dev The Controller holds all the collateral used to mint options. Options need to be created through the
/// OptionsFactory first.
contract Controller is IController, EIP712MetaTransaction {
    using SafeTransferLib for IERC20;
    using Actions for ActionArgs;

    OptionsFactory public immutable optionsFactory;

    OperateProxy public immutable operateProxy;

    QuantCalculator public immutable quantCalculator;

    OracleRegistry public immutable oracleRegistry;

    CollateralToken public immutable collateralToken;

    constructor(
        string memory _name,
        string memory _version,
        string memory _uri,
        address _oracleRegistry,
        address _strikeAsset,
        address _priceRegistry,
        address _assetsRegistry,
        QToken _qTokenImplementation
    )
        EIP712MetaTransaction(_name, _version)
    {
        require(_oracleRegistry != address(0), "Controller: invalid OracleRegistry address");
        require(_strikeAsset != address(0), "Controller: invalid StrikeAsset address");
        require(_priceRegistry != address(0), "Controller: invalid PriceRegistry address");
        require(_assetsRegistry != address(0), "Controller: invalid AssetsRegistry address");

        oracleRegistry = OracleRegistry(_oracleRegistry);

        operateProxy = new OperateProxy();
        collateralToken = new CollateralToken(_name, _version, _uri);

        optionsFactory = new OptionsFactory(
            _strikeAsset,
            address(collateralToken),
            address(this),
            _oracleRegistry,
            _assetsRegistry,
            _qTokenImplementation
        );

        quantCalculator = new QuantCalculator(
            address(optionsFactory),
            _assetsRegistry,
            _priceRegistry
        );

        collateralToken.setOptionsFactory(address(optionsFactory));
    }

    /// @inheritdoc IController
    function operate(ActionArgs[] memory _actions) external override {
        /// WARNING: DO NOT UNDER ANY CIRCUMSTANCES APPROVE THE OperateProxy TO
        /// SPEND YOUR FUNDS (using CALL action) OR ANYONE WILL BE ABLE TO SPEND THEM AFTER YOU!!!

        uint256 length = _actions.length;
        for (uint256 i = 0; i < length;) {
            ActionArgs memory action = _actions[i];

            if (action.actionType == ActionType.MintOption) {
                (address to, address qToken, uint256 amount) = action.parseMintOptionArgs();
                mintOptionsPosition(to, qToken, amount);
            } else if (action.actionType == ActionType.MintSpread) {
                (address qTokenToMint, address qTokenForCollateral, uint256 amount) = action.parseMintSpreadArgs();
                mintSpread(qTokenToMint, qTokenForCollateral, amount);
            } else if (action.actionType == ActionType.Exercise) {
                (address qToken, uint256 amount) = action.parseExerciseArgs();
                exercise(qToken, amount);
            } else if (action.actionType == ActionType.ClaimCollateral) {
                (uint256 collateralTokenId, uint256 amount) = action.parseClaimCollateralArgs();
                claimCollateral(collateralTokenId, amount);
            } else if (action.actionType == ActionType.Neutralize) {
                (uint256 collateralTokenId, uint256 amount) = action.parseNeutralizeArgs();
                neutralizePosition(collateralTokenId, amount);
            } else if (action.actionType == ActionType.QTokenPermit) {
                (
                    address qToken,
                    address owner,
                    address spender,
                    uint256 value,
                    uint256 deadline,
                    uint8 v,
                    bytes32 r,
                    bytes32 s
                ) = action.parseQTokenPermitArgs();
                _qTokenPermit(qToken, owner, spender, value, deadline, v, r, s);
            } else if (action.actionType == ActionType.CollateralTokenApproval) {
                (
                    address owner,
                    address operator,
                    bool approved,
                    uint256 nonce,
                    uint256 deadline,
                    uint8 v,
                    bytes32 r,
                    bytes32 s
                ) = action.parseCollateralTokenApprovalArgs();
                _collateralTokenApproval(owner, operator, approved, nonce, deadline, v, r, s);
            } else {
                (address callee, bytes memory data) = action.parseCallArgs();
                _call(callee, data);
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IController
    function mintOptionsPosition(address _to, address _qToken, uint256 _amount) public override {
        /// -------------------------------------------------------------------
        /// Checks
        /// -------------------------------------------------------------------

        // Get the collateral required to mint the specified amount of options
        // The zero address is passed as the second argument as it's only used
        // for spreads
        (address collateral, uint256 collateralAmount) =
            quantCalculator.getCollateralRequirement(_qToken, address(0), _amount);

        _checkIfUnexpiredQToken(_qToken);

        _checkIfActiveOracle(_qToken);

        /// -------------------------------------------------------------------
        /// Effects
        /// -------------------------------------------------------------------

        // Mint the option's long tokens to the recipient's address
        QToken(_qToken).mint(_to, _amount);

        emit OptionsPositionMinted(_to, _msgSender(), _qToken, _amount, collateral, collateralAmount);

        /// -------------------------------------------------------------------
        /// Interactions
        /// -------------------------------------------------------------------

        // pull the required collateral from the caller/signer
        IERC20(collateral).safeTransferFrom(_msgSender(), address(this), collateralAmount);

        // There's no need to check if the collateralTokenId exists before minting the
        // short tokens because if the QToken is valid, then it's guaranteed that the
        // respective CollateralToken has already also been created by the OptionsFactory
        uint256 collateralTokenId = collateralToken.getCollateralTokenId(_qToken, address(0));

        // Mint the option's short tokens to the recipient's address
        collateralToken.mintCollateralToken(_to, collateralTokenId, _amount);
    }

    /// @inheritdoc IController
    function mintSpread(address _qTokenToMint, address _qTokenForCollateral, uint256 _amount) public override {
        /// -------------------------------------------------------------------
        /// Checks
        /// -------------------------------------------------------------------

        require(_qTokenToMint != _qTokenForCollateral, "Controller: Can only create a spread with different tokens");

        // Calculate the extra collateral required to create the spread.
        // A positive value for debit spreads and zero for credit spreads.
        (address collateral, uint256 collateralAmount) =
            quantCalculator.getCollateralRequirement(_qTokenToMint, _qTokenForCollateral, _amount);

        // Check if the QTokens are unexpired
        // Only one of them needs to be checked since `getCollateralRequirement`
        // requires that both QTokens have the same expiry
        _checkIfUnexpiredQToken(_qTokenToMint);

        // Check if the QTokens are using active oracles
        // Only one of them needs to be checked since `getCollateralRequirement`
        // requires that both QTokens have the same oracle
        _checkIfActiveOracle(_qTokenToMint);

        /// -------------------------------------------------------------------
        /// Effects
        /// -------------------------------------------------------------------

        // Burn the QToken being shorted
        QToken(_qTokenForCollateral).burn(_msgSender(), _amount);

        // Check if the CollateralToken representing this specific spread has already been created
        // Create it if it hasn't
        uint256 collateralTokenId = collateralToken.getCollateralTokenId(_qTokenToMint, _qTokenForCollateral);
        (, address qTokenAsCollateral) = collateralToken.idToInfo(collateralTokenId);
        if (qTokenAsCollateral == address(0)) {
            require(
                collateralTokenId == collateralToken.createSpreadCollateralToken(_qTokenToMint, _qTokenForCollateral),
                "Controller: failed creating the collateral token to represent the spread"
            );
        }

        // Mint the long tokens for the new spread position
        QToken(_qTokenToMint).mint(_msgSender(), _amount);

        emit SpreadMinted(_msgSender(), _qTokenToMint, _qTokenForCollateral, _amount, collateral, collateralAmount);

        /// -------------------------------------------------------------------
        /// Interactions
        /// -------------------------------------------------------------------

        // Transfer in any collateral required for the spread
        if (collateralAmount > 0) {
            IERC20(collateral).safeTransferFrom(_msgSender(), address(this), collateralAmount);
        }

        // Mint the short tokens for the new spread position
        collateralToken.mintCollateralToken(_msgSender(), collateralTokenId, _amount);
    }

    /// @inheritdoc IController
    function exercise(address _qToken, uint256 _amount) public override {
        QToken qToken = QToken(_qToken);

        /// -------------------------------------------------------------------
        /// Checks
        /// -------------------------------------------------------------------

        require(block.timestamp > qToken.expiryTime(), "Controller: Can not exercise options before their expiry");

        // if the amount is 0, the entire position will be exercised
        if (_amount == 0) {
            _amount = qToken.balanceOf(_msgSender());
        }

        // Use the QuantCalculator to check how much the sender/signer is due.
        // Will only be a positive value for options that expired In The Money.
        (bool isSettled, address payoutToken, uint256 exerciseTotal) =
            quantCalculator.getExercisePayout(_qToken, _amount);

        require(isSettled, "Controller: Cannot exercise unsettled options");

        /// -------------------------------------------------------------------
        /// Effects
        /// -------------------------------------------------------------------

        // Burn the long tokens
        qToken.burn(_msgSender(), _amount);

        emit OptionsExercised(_msgSender(), _qToken, _amount, exerciseTotal, payoutToken);

        /// -------------------------------------------------------------------
        /// Interactions
        /// -------------------------------------------------------------------

        // Transfer any profit due after expiration
        if (exerciseTotal > 0) {
            IERC20(payoutToken).safeTransfer(_msgSender(), exerciseTotal);
        }
    }

    /// @inheritdoc IController
    function claimCollateral(uint256 _collateralTokenId, uint256 _amount) public override {
        /// -------------------------------------------------------------------
        /// Checks
        /// -------------------------------------------------------------------

        // Use the QuantCalculator to check how much collateral the sender/signer is due.
        (uint256 returnableCollateral, address collateralAsset, uint256 amountToClaim) =
            quantCalculator.calculateClaimableCollateral(_collateralTokenId, _amount, _msgSender());

        /// -------------------------------------------------------------------
        /// Effects
        /// -------------------------------------------------------------------

        // Burn the short tokens
        collateralToken.burnCollateralToken(_msgSender(), _collateralTokenId, amountToClaim);

        emit CollateralClaimed(_msgSender(), _collateralTokenId, amountToClaim, returnableCollateral, collateralAsset);

        /// -------------------------------------------------------------------
        /// Interactions
        /// -------------------------------------------------------------------

        // Transfer any collateral due after expiration
        if (returnableCollateral > 0) {
            IERC20(collateralAsset).safeTransfer(_msgSender(), returnableCollateral);
        }
    }

    /// @inheritdoc IController
    function neutralizePosition(uint256 _collateralTokenId, uint256 _amount) public override {
        /// -------------------------------------------------------------------
        /// Checks
        /// -------------------------------------------------------------------

        (address qTokenShort, address qTokenLong) = collateralToken.idToInfo(_collateralTokenId);

        if (_amount == 0) {
            //get the amount of CollateralTokens owned
            uint256 collateralTokensOwned = collateralToken.balanceOf(_msgSender(), _collateralTokenId);

            //get the amount of QTokens owned
            uint256 qTokensOwned = QToken(qTokenShort).balanceOf(_msgSender());

            // the size of the position that can be neutralized
            _amount = qTokensOwned < collateralTokensOwned ? qTokensOwned : collateralTokensOwned;
        }

        // use the QuantCalculator to check how much collateral the sender/signer is due
        // for closing the neutral position
        (address collateralType, uint256 collateralOwed) =
            quantCalculator.getNeutralizationPayout(qTokenShort, qTokenLong, _amount);

        /// -------------------------------------------------------------------
        /// Effects
        /// -------------------------------------------------------------------

        // burn the short tokens
        QToken(qTokenShort).burn(_msgSender(), _amount);

        // burn the long tokens
        collateralToken.burnCollateralToken(_msgSender(), _collateralTokenId, _amount);

        //give the user their long tokens (if any, in case of CollateralTokens representing a spread)
        if (qTokenLong != address(0)) {
            QToken(qTokenLong).mint(_msgSender(), _amount);
        }

        emit NeutralizePosition(_msgSender(), qTokenShort, _amount, collateralOwed, collateralType, qTokenLong);

        /// -------------------------------------------------------------------
        /// Interactions
        /// -------------------------------------------------------------------

        // tranfer the collateral owed
        IERC20(collateralType).safeTransfer(_msgSender(), collateralOwed);
    }

    /// @notice Allows a QToken owner to approve a spender to transfer a specified amount of tokens on their behalf.
    /// @param _qToken The QToken to be approved.
    /// @param _spender The address of the spender.
    /// @param _value The amount of tokens to be approved for spending.
    /// @param _deadline Timestamp at which the permit signature expires.
    /// @param _v The signature's v value.
    /// @param _r The signature's r value.
    /// @param _s The signature's s value.
    function _qTokenPermit(
        address _qToken,
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        internal
    {
        require(optionsFactory.isQToken(_qToken), "Controller: not a QToken for calling permit");

        QToken(_qToken).permit(_owner, _spender, _value, _deadline, _v, _r, _s);
    }

    /// @notice Allows a CollateralToken owner to either approve an operator address
    /// to spend all of their tokens on their behalf, or to remove a prior approval.
    /// @param _owner The address of the owner of the CollateralToken.
    /// @param _operator The address of the operator to be approved or removed.
    /// @param _approved Whether the operator is being approved or removed.
    /// @param _nonce The nonce for the approval through a meta transaction.
    /// @param _deadline Timestamp at which the approval signature expires.
    /// @param _v The signature's v value.
    /// @param _r The signature's r value.
    /// @param _s The signature's s value.
    function _collateralTokenApproval(
        address _owner,
        address _operator,
        bool _approved,
        uint256 _nonce,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        internal
    {
        collateralToken.metaSetApprovalForAll(_owner, _operator, _approved, _nonce, _deadline, _v, _r, _s);
    }

    /// @notice Allows a sender/signer to make external calls to any other contract.
    /// WARNING: DO NOT UNDER ANY CIRCUMSTANCES APPROVE THE OperateProxy TO
    /// SPEND YOUR FUNDS OR ANYONE WILL BE ABLE TO SPEND THEM AFTER YOU!!!
    /// @dev A separate OperateProxy contract is used to make the external calls so
    /// that the Controller, which holds funds and has special privileges in the Quant
    /// Protocol, is never the `msg.sender` in any of those external calls.
    /// @param _callee The address of the contract to be called.
    /// @param _data The calldata to be sent to the contract.
    function _call(address _callee, bytes memory _data) internal {
        operateProxy.callFunction(_callee, _data);
    }

    /// @notice Checks if the given QToken has not expired yet, reverting otherwise
    /// @param _qToken The address of the QToken to check.
    function _checkIfUnexpiredQToken(address _qToken) internal view {
        require(QToken(_qToken).expiryTime() > block.timestamp, "Controller: Cannot mint expired options");
    }

    /// @notice Checks if the oracle set during the option's creation through the OptionsFactory
    /// is an active oracle in the OracleRegistry
    /// @param _qToken The address of the QToken to check.
    function _checkIfActiveOracle(address _qToken) internal view {
        require(
            oracleRegistry.isOracleActive(QToken(_qToken).oracle()),
            "Controller: Can't mint an options position as the oracle is inactive"
        );
    }
}
