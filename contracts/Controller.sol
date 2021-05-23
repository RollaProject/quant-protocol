// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma abicoder v2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./QuantConfig.sol";
import "./interfaces/IOptionsFactory.sol";
import "./interfaces/IOracleRegistry.sol";
import "./options/QToken.sol";
import "./interfaces/ICollateralToken.sol";
import "./interfaces/IAssetsRegistry.sol";
import "./interfaces/IController.sol";
import "./libraries/ProtocolValue.sol";
import "./libraries/QuantMath.sol";
import "./libraries/FundsCalculator.sol";
import "hardhat/console.sol";

contract Controller is IController {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    using QuantMath for uint256;
    using QuantMath for int256;
    using QuantMath for QuantMath.FixedPointInt;

    IOptionsFactory public immutable override optionsFactory;

    uint8 public constant override OPTIONS_DECIMALS = 18;

    modifier validQToken(address _qToken) {
        require(
            optionsFactory.isQToken(_qToken),
            "Controller: Option needs to be created by the factory first"
        );

        QToken qToken = QToken(_qToken);

        require(
            qToken.expiryTime() > block.timestamp,
            "Controller: Cannot mint expired options"
        );

        _;
    }

    constructor(address _optionsFactory) {
        optionsFactory = IOptionsFactory(_optionsFactory);
    }

    function mintOptionsPosition(
        address _to,
        address _qToken,
        uint256 _optionsAmount
    ) external override validQToken(_qToken) {
        QToken qToken = QToken(_qToken);

        require(
            IOracleRegistry(
                optionsFactory.quantConfig().protocolAddresses(
                    ProtocolValue.encode("oracleRegistry")
                )
            )
                .isOracleActive(qToken.oracle()),
            "Controller: Can't mint an options position as the oracle is inactive"
        );

        (address collateral, uint256 collateralAmount) =
            getCollateralRequirement(_qToken, address(0), _optionsAmount);

        IERC20(collateral).safeTransferFrom(
            msg.sender,
            address(this),
            collateralAmount
        );

        // Mint the options to the sender's address
        qToken.mint(_to, _optionsAmount);
        uint256 collateralTokenId =
            optionsFactory.collateralToken().getCollateralTokenId(
                _qToken,
                address(0)
            );

        // There's no need to check if the collateralTokenId exists before minting because if the QToken is valid,
        // then it's guaranteed that the respective CollateralToken has already also been created by the OptionsFactory
        optionsFactory.collateralToken().mintCollateralToken(
            _to,
            collateralTokenId,
            _optionsAmount
        );

        emit OptionsPositionMinted(_to, msg.sender, _qToken, _optionsAmount);
    }

    function mintSpread(
        address _qTokenToMint,
        address _qTokenForCollateral,
        uint256 _optionsAmount
    )
        external
        override
        validQToken(_qTokenToMint)
        validQToken(_qTokenForCollateral)
    {
        require(
            _qTokenToMint != _qTokenForCollateral,
            "Controller: Can only create a spread with different tokens"
        );

        QToken qTokenToMint = QToken(_qTokenToMint);
        QToken qTokenForCollateral = QToken(_qTokenForCollateral);

        (address collateral, uint256 collateralAmount) =
            getCollateralRequirement(
                _qTokenToMint,
                _qTokenForCollateral,
                _optionsAmount
            );

        qTokenForCollateral.burn(msg.sender, _optionsAmount);

        if (collateralAmount > 0) {
            IERC20(collateral).safeTransferFrom(
                msg.sender,
                address(this),
                collateralAmount
            );
        }

        // Check if the corresponding CollateralToken has already been created
        // Create it if it hasn't
        uint256 collateralTokenId =
            optionsFactory.collateralToken().getCollateralTokenId(
                _qTokenToMint,
                _qTokenForCollateral
            );
        (, address qTokenAsCollateral) =
            optionsFactory.collateralToken().idToInfo(collateralTokenId);
        if (qTokenAsCollateral == address(0)) {
            optionsFactory.collateralToken().createCollateralToken(
                _qTokenToMint,
                _qTokenForCollateral
            );
        }

        optionsFactory.collateralToken().mintCollateralToken(
            msg.sender,
            collateralTokenId,
            _optionsAmount
        );

        qTokenToMint.mint(msg.sender, _optionsAmount);

        emit SpreadMinted(
            msg.sender,
            _qTokenToMint,
            _qTokenForCollateral,
            _optionsAmount
        );
    }

    function exercise(address _qToken, uint256 _amount) external override {
        QToken qToken = QToken(_qToken);
        require(
            block.timestamp > qToken.expiryTime(),
            "Controller: Can not exercise options before their expiry"
        );

        uint256 amountToExercise;
        if (_amount == 0) {
            amountToExercise = qToken.balanceOf(msg.sender);
        } else {
            amountToExercise = _amount;
        }

        (bool isSettled, address payoutToken, uint256 payoutAmount) =
            getPayout(_qToken, amountToExercise);

        require(isSettled, "Controller: Cannot exercise unsettled options");

        qToken.burn(msg.sender, amountToExercise);

        if (payoutAmount > 0) {
            IERC20(payoutToken).transfer(msg.sender, payoutAmount);
        }

        emit OptionsExercised(
            msg.sender,
            _qToken,
            amountToExercise,
            payoutAmount,
            payoutToken
        );
    }

    function claimCollateral(uint256 _collateralTokenId, uint256 _amount)
        external
        override
    {
        (
            uint256 returnableCollateral,
            address collateralAsset,
            uint256 amountToClaim
        ) = calculateClaimableCollateral(_collateralTokenId, _amount);

        optionsFactory.collateralToken().burnCollateralToken(
            msg.sender,
            _collateralTokenId,
            amountToClaim
        );

        if (returnableCollateral > 0) {
            IERC20(collateralAsset).safeTransfer(
                msg.sender,
                returnableCollateral
            );
        }

        emit CollateralClaimed(
            msg.sender,
            _collateralTokenId,
            amountToClaim,
            returnableCollateral,
            collateralAsset
        );
    }

    function calculateClaimableCollateral(
        uint256 _collateralTokenId,
        uint256 _amount
    )
        public
        view
        returns (
            uint256 returnableCollateral,
            address collateralAsset,
            uint256 amountToClaim
        )
    {
        (address _qTokenShort, address qTokenAsCollateral) =
            optionsFactory.collateralToken().idToInfo(_collateralTokenId);

        require(
            _qTokenShort != address(0),
            "Controller: Can not claim collateral from non-existing option"
        );

        QToken qTokenShort = QToken(_qTokenShort);

        require(
            block.timestamp > qTokenShort.expiryTime(),
            "Controller: Can not claim collateral from options before their expiry"
        );
        require(
            qTokenShort.getOptionPriceStatus() == PriceStatus.SETTLED,
            "Controller: Can not claim collateral before option is settled"
        );

        amountToClaim = _amount == 0
            ? optionsFactory.collateralToken().balanceOf(
                msg.sender,
                _collateralTokenId
            )
            : _amount;

        address qTokenLong;
        QuantMath.FixedPointInt memory payoutFromLong;

        PriceRegistry priceRegistry =
            PriceRegistry(
                optionsFactory.quantConfig().protocolAddresses(
                    ProtocolValue.encode("priceRegistry")
                )
            );

        uint256 expiryPrice =
            priceRegistry.getSettlementPrice(
                qTokenShort.oracle(),
                qTokenShort.underlyingAsset(),
                qTokenShort.expiryTime()
            );

        IAssetsRegistry assetsRegistry =
            IAssetsRegistry(
                optionsFactory.quantConfig().protocolAddresses(
                    ProtocolValue.encode("assetsRegistry")
                )
            );

        if (qTokenAsCollateral != address(0)) {
            qTokenLong = qTokenAsCollateral;

            (, payoutFromLong, ) = FundsCalculator.getPayout(
                qTokenLong,
                amountToClaim,
                OPTIONS_DECIMALS,
                expiryPrice,
                assetsRegistry
            );
        } else {
            qTokenLong = address(0);
            payoutFromLong = int256(0).fromUnscaledInt();
        }

        uint8 payoutDecimals;
        QuantMath.FixedPointInt memory collateralRequirement;
        (
            collateralAsset,
            collateralRequirement,
            payoutDecimals
        ) = FundsCalculator.getCollateralRequirement(
            _qTokenShort,
            qTokenLong,
            amountToClaim,
            OPTIONS_DECIMALS,
            assetsRegistry
        );

        (, QuantMath.FixedPointInt memory payoutFromShort, ) =
            FundsCalculator.getPayout(
                _qTokenShort,
                amountToClaim,
                OPTIONS_DECIMALS,
                expiryPrice,
                assetsRegistry
            );

        returnableCollateral = payoutFromLong
            .add(collateralRequirement)
            .sub(payoutFromShort)
            .toScaledUint(payoutDecimals, true);
    }

    function neutralizePosition(uint256 _collateralTokenId, uint256 _amount)
        external
        override
    {
        ICollateralToken collateralToken = optionsFactory.collateralToken();
        (address qTokenShort, address qTokenAsCollateral) =
            collateralToken.idToInfo(_collateralTokenId);

        //get the amount of collateral tokens owned
        uint256 collateralTokensOwned =
            collateralToken.balanceOf(msg.sender, _collateralTokenId);

        //get the amount of qTokens owned
        uint256 qTokensOwned = QToken(qTokenShort).balanceOf(msg.sender);

        //the amount of position that can be neutralized
        uint256 maxNeutralizable =
            qTokensOwned > collateralTokensOwned
                ? qTokensOwned
                : collateralTokensOwned;

        uint256 amountToNeutralize;

        if (_amount != 0) {
            require(
                _amount <= maxNeutralizable,
                "Controller: Tried to neutralize more than balance"
            );
            amountToNeutralize = _amount;
        } else {
            amountToNeutralize = maxNeutralizable;
        }

        IAssetsRegistry assetsRegistry =
            IAssetsRegistry(
                optionsFactory.quantConfig().protocolAddresses(
                    ProtocolValue.encode("assetsRegistry")
                )
            );

        address collateralType;
        uint256 collateralOwed;

        {
            QuantMath.FixedPointInt memory collateralOwedFP;
            uint8 collateralDecimals;

            (
                collateralType,
                collateralOwedFP,
                collateralDecimals
            ) = FundsCalculator.getCollateralRequirement(
                qTokenShort,
                address(0),
                amountToNeutralize,
                OPTIONS_DECIMALS,
                assetsRegistry
            );

            collateralOwed = collateralOwedFP.toScaledUint(
                collateralDecimals,
                true
            );
        }

        QToken(qTokenShort).burn(msg.sender, amountToNeutralize);

        collateralToken.burnCollateralToken(
            msg.sender,
            _collateralTokenId,
            amountToNeutralize
        );

        IERC20(collateralType).safeTransfer(msg.sender, collateralOwed);

        //give the user their long tokens (if any)
        if (qTokenAsCollateral != address(0)) {
            QToken(qTokenAsCollateral).mint(msg.sender, amountToNeutralize);
        }

        emit NeutralizePosition(
            msg.sender,
            qTokenShort,
            amountToNeutralize,
            collateralOwed,
            collateralType,
            qTokenAsCollateral
        );
    }

    function getCollateralRequirement(
        address _qTokenToMint,
        address _qTokenForCollateral,
        uint256 _optionsAmount
    )
        public
        view
        override
        returns (address collateral, uint256 collateralAmount)
    {
        IAssetsRegistry assetsRegistry =
            IAssetsRegistry(
                optionsFactory.quantConfig().protocolAddresses(
                    ProtocolValue.encode("assetsRegistry")
                )
            );

        QuantMath.FixedPointInt memory collateralAmountFP;
        uint8 decimals;

        (collateral, collateralAmountFP, decimals) = FundsCalculator
            .getCollateralRequirement(
            _qTokenToMint,
            _qTokenForCollateral,
            _optionsAmount,
            OPTIONS_DECIMALS,
            assetsRegistry
        );

        collateralAmount = collateralAmountFP.toScaledUint(decimals, false);
    }

    //todo: ensure the oracle price is normalized to the amount of decimals in the strikeAsset (e.g., USDC)
    function getPayout(address _qToken, uint256 _amount)
        public
        view
        override
        returns (
            bool isSettled,
            address payoutToken,
            uint256 payoutAmount
        )
    {
        QToken qToken = QToken(_qToken);
        isSettled = qToken.getOptionPriceStatus() == PriceStatus.SETTLED;
        if (!isSettled) {
            return (false, address(0), 0);
        } else {
            isSettled = true;
        }

        QuantMath.FixedPointInt memory payout;

        PriceRegistry priceRegistry =
            PriceRegistry(
                optionsFactory.quantConfig().protocolAddresses(
                    ProtocolValue.encode("priceRegistry")
                )
            );

        IAssetsRegistry assetsRegistry =
            IAssetsRegistry(
                optionsFactory.quantConfig().protocolAddresses(
                    ProtocolValue.encode("assetsRegistry")
                )
            );

        address underlyingAsset = QToken(_qToken).underlyingAsset();

        uint256 expiryPrice =
            priceRegistry.getSettlementPrice(
                QToken(_qToken).oracle(),
                underlyingAsset,
                QToken(_qToken).expiryTime()
            );

        uint8 payoutDecimals;

        (payoutToken, payout, payoutDecimals) = FundsCalculator
            .getPayout(
            _qToken,
            _amount,
            OPTIONS_DECIMALS,
            expiryPrice,
            assetsRegistry
        );

        payoutAmount = payout.toScaledUint(payoutDecimals, true);
    }
}
