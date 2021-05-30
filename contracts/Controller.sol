// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./QuantConfig.sol";
import "./utils/EIP712MetaTransaction.sol";
import "./utils/OperateProxy.sol";
import "./interfaces/IQToken.sol";
import "./interfaces/IOracleRegistry.sol";
import "./interfaces/ICollateralToken.sol";
import "./interfaces/IController.sol";
import "./interfaces/IOperateProxy.sol";
import "./interfaces/IQuantCalculator.sol";
import "./interfaces/IOptionsFactory.sol";
import "./libraries/ProtocolValue.sol";
import "./libraries/QuantMath.sol";
import "./libraries/OptionsUtils.sol";
import "./libraries/Actions.sol";
import "./libraries/external/strings.sol";

contract Controller is
    IController,
    EIP712MetaTransaction,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    using QuantMath for QuantMath.FixedPointInt;
    using Actions for ActionArgs;
    using strings for *;

    address public override optionsFactory;

    address public override operateProxy;

    address public override quantCalculator;

    modifier validQToken(address _qToken) {
        //TODO: Better messaging here...
        require(
            IOptionsFactory(optionsFactory).isQToken(_qToken),
            "Controller: Option needs to be created by the factory first"
        );

        IQToken qToken = IQToken(_qToken);

        require(
            qToken.expiryTime() > block.timestamp,
            "Controller: Cannot mint expired options"
        );

        _;
    }

    function operate(ActionArgs[] memory _actions)
        external
        override
        nonReentrant
        returns (bool)
    {
        for (uint256 i = 0; i < _actions.length; i++) {
            ActionArgs memory action = _actions[i];
            string memory actionType = action.actionType;

            if (_equalStrings(actionType, "MINT_OPTION")) {
                _mintOptionsPosition(action.parseMintOptionArgs());
            } else if (_equalStrings(actionType, "MINT_SPREAD")) {
                _mintSpread(action.parseMintSpreadArgs());
            } else if (_equalStrings(actionType, "EXERCISE")) {
                _exercise(action.parseExerciseArgs());
            } else if (_equalStrings(actionType, "CLAIM_COLLATERAL")) {
                _claimCollateral(action.parseClaimCollateralArgs());
            } else if (_equalStrings(actionType, "NEUTRALIZE")) {
                _neutralizePosition(action.parseNeutralizeArgs());
            } else {
                require(
                    _equalStrings(actionType, "CALL"),
                    "Controller: Invalid action type"
                );
                _call(action.parseCallArgs());
            }
        }

        return true;
    }

    function initialize(
        string memory _name,
        string memory _version,
        address _optionsFactory,
        address _quantCalculator
    ) public override initializer {
        __ReentrancyGuard_init();
        EIP712MetaTransaction.initializeEIP712(_name, _version);
        optionsFactory = _optionsFactory;
        operateProxy = address(new OperateProxy());
        quantCalculator = _quantCalculator;
    }

    function _mintOptionsPosition(Actions.MintOptionArgs memory _args)
        internal
        validQToken(_args.qToken)
        returns (uint256)
    {
        IQToken qToken = IQToken(_args.qToken);

        require(
            IOracleRegistry(
                IOptionsFactory(optionsFactory).quantConfig().protocolAddresses(
                    ProtocolValue.encode("oracleRegistry")
                )
            )
                .isOracleActive(qToken.oracle()),
            "Controller: Can't mint an options position as the oracle is inactive"
        );

        (address collateral, uint256 collateralAmount) =
            IQuantCalculator(quantCalculator).getCollateralRequirement(
                _args.qToken,
                address(0),
                optionsFactory,
                _args.amount
            );

        IERC20(collateral).safeTransferFrom(
            _msgSender(),
            address(this),
            collateralAmount
        );

        // Mint the options to the sender's address
        qToken.mint(_args.to, _args.amount);
        uint256 collateralTokenId =
            IOptionsFactory(optionsFactory)
                .collateralToken()
                .getCollateralTokenId(_args.qToken, address(0));

        // There's no need to check if the collateralTokenId exists before minting because if the QToken is valid,
        // then it's guaranteed that the respective CollateralToken has already also been created by the OptionsFactory
        IOptionsFactory(optionsFactory).collateralToken().mintCollateralToken(
            _args.to,
            collateralTokenId,
            _args.amount
        );

        emit OptionsPositionMinted(
            _args.to,
            _msgSender(),
            _args.qToken,
            _args.amount
        );

        return collateralTokenId;
    }

    function _mintSpread(Actions.MintSpreadArgs memory _args)
        internal
        validQToken(_args.qTokenToMint)
        validQToken(_args.qTokenForCollateral)
        returns (uint256)
    {
        require(
            _args.qTokenToMint != _args.qTokenForCollateral,
            "Controller: Can only create a spread with different tokens"
        );

        IQToken qTokenToMint = IQToken(_args.qTokenToMint);
        IQToken qTokenForCollateral = IQToken(_args.qTokenForCollateral);

        (address collateral, uint256 collateralAmount) =
            IQuantCalculator(quantCalculator).getCollateralRequirement(
                _args.qTokenToMint,
                _args.qTokenForCollateral,
                optionsFactory,
                _args.amount
            );

        qTokenForCollateral.burn(_msgSender(), _args.amount);

        if (collateralAmount > 0) {
            IERC20(collateral).safeTransferFrom(
                _msgSender(),
                address(this),
                collateralAmount
            );
        }

        // Check if the corresponding CollateralToken has already been created
        // Create it if it hasn't
        uint256 collateralTokenId =
            IOptionsFactory(optionsFactory)
                .collateralToken()
                .getCollateralTokenId(
                _args.qTokenToMint,
                _args.qTokenForCollateral
            );
        (, address qTokenAsCollateral) =
            IOptionsFactory(optionsFactory).collateralToken().idToInfo(
                collateralTokenId
            );
        if (qTokenAsCollateral == address(0)) {
            IOptionsFactory(optionsFactory)
                .collateralToken()
                .createCollateralToken(
                _args.qTokenToMint,
                _args.qTokenForCollateral
            );
        }

        IOptionsFactory(optionsFactory).collateralToken().mintCollateralToken(
            _msgSender(),
            collateralTokenId,
            _args.amount
        );

        qTokenToMint.mint(_msgSender(), _args.amount);

        emit SpreadMinted(
            _msgSender(),
            _args.qTokenToMint,
            _args.qTokenForCollateral,
            _args.amount
        );

        return collateralTokenId;
    }

    function _exercise(Actions.ExerciseArgs memory _args) internal {
        IQToken qToken = IQToken(_args.qToken);
        require(
            block.timestamp > qToken.expiryTime(),
            "Controller: Can not exercise options before their expiry"
        );

        uint256 amountToExercise;
        if (_args.amount == 0) {
            amountToExercise = qToken.balanceOf(_msgSender());
        } else {
            amountToExercise = _args.amount;
        }

        (bool isSettled, address payoutToken, uint256 exerciseTotal) =
            IQuantCalculator(quantCalculator).getExercisePayout(
                _args.qToken,
                optionsFactory,
                amountToExercise
            );

        require(isSettled, "Controller: Cannot exercise unsettled options");

        qToken.burn(_msgSender(), amountToExercise);

        if (exerciseTotal > 0) {
            IERC20(payoutToken).transfer(_msgSender(), exerciseTotal);
        }

        emit OptionsExercised(
            _msgSender(),
            _args.qToken,
            amountToExercise,
            exerciseTotal,
            payoutToken
        );
    }

    function _claimCollateral(Actions.ClaimCollateralArgs memory _args)
        internal
    {
        (
            uint256 returnableCollateral,
            address collateralAsset,
            uint256 amountToClaim
        ) =
            IQuantCalculator(quantCalculator).calculateClaimableCollateral(
                _args.collateralTokenId,
                _args.amount,
                optionsFactory,
                _msgSender()
            );

        IOptionsFactory(optionsFactory).collateralToken().burnCollateralToken(
            _msgSender(),
            _args.collateralTokenId,
            amountToClaim
        );

        if (returnableCollateral > 0) {
            IERC20(collateralAsset).safeTransfer(
                _msgSender(),
                returnableCollateral
            );
        }

        emit CollateralClaimed(
            _msgSender(),
            _args.collateralTokenId,
            amountToClaim,
            returnableCollateral,
            collateralAsset
        );
    }

    function _neutralizePosition(Actions.NeutralizeArgs memory _args) internal {
        ICollateralToken collateralToken =
            IOptionsFactory(optionsFactory).collateralToken();
        (address qTokenShort, address qTokenLong) =
            collateralToken.idToInfo(_args.collateralTokenId);

        //get the amount of collateral tokens owned
        uint256 collateralTokensOwned =
            collateralToken.balanceOf(_msgSender(), _args.collateralTokenId);

        //get the amount of qTokens owned
        uint256 qTokensOwned = IQToken(qTokenShort).balanceOf(_msgSender());

        //the amount of position that can be neutralized
        uint256 maxNeutralizable =
            qTokensOwned > collateralTokensOwned
                ? qTokensOwned
                : collateralTokensOwned;

        uint256 amountToNeutralize;

        if (_args.amount != 0) {
            require(
                _args.amount <= maxNeutralizable,
                "Controller: Tried to neutralize more than balance"
            );
            amountToNeutralize = _args.amount;
        } else {
            amountToNeutralize = maxNeutralizable;
        }

        (address collateralType, uint256 collateralOwed) =
            IQuantCalculator(quantCalculator).getNeutralizationPayout(
                qTokenLong,
                qTokenShort,
                amountToNeutralize,
                optionsFactory
            );

        IQToken(qTokenShort).burn(_msgSender(), amountToNeutralize);

        collateralToken.burnCollateralToken(
            _msgSender(),
            _args.collateralTokenId,
            amountToNeutralize
        );

        IERC20(collateralType).safeTransfer(_msgSender(), collateralOwed);

        //give the user their long tokens (if any)
        if (qTokenLong != address(0)) {
            IQToken(qTokenLong).mint(_msgSender(), amountToNeutralize);
        }

        emit NeutralizePosition(
            _msgSender(),
            qTokenShort,
            amountToNeutralize,
            collateralOwed,
            collateralType,
            qTokenLong
        );
    }

    function _call(Actions.CallArgs memory _args) internal {
        IOperateProxy(operateProxy).callFunction(_args.callee, _args.data);
    }

    function _equalStrings(string memory str1, string memory str2)
        internal
        pure
        returns (bool)
    {
        return str1.toSlice().equals(str2.toSlice());
    }
}
