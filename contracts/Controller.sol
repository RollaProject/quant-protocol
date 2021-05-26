// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma abicoder v2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./QuantConfig.sol";
import "./EIP712MetaTransaction.sol";
import "./interfaces/IOptionsFactory.sol";
import "./interfaces/IOracleRegistry.sol";
import "./interfaces/IPriceRegistry.sol";
import "./options/QToken.sol";
import "./interfaces/ICollateralToken.sol";
import "./interfaces/IAssetsRegistry.sol";
import "./interfaces/IController.sol";
import "./libraries/ProtocolValue.sol";
import "./libraries/QuantMath.sol";
import "./libraries/FundsCalculator.sol";
import "./libraries/OptionsUtils.sol";

contract Controller is IController, EIP712MetaTransaction, ReentrancyGuard {
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

    //TODO: Inject _quantConfig in here and use instead of using factory
    constructor(address _optionsFactory)
        EIP712MetaTransaction("Quant Protocol", "0.2.0")
    {
        optionsFactory = IOptionsFactory(_optionsFactory);
    }

    function mintOptionsPosition(
        address _to,
        address _qToken,
        uint256 _optionsAmount
    ) external override validQToken(_qToken) nonReentrant() {
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
            _msgSender(),
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

        emit OptionsPositionMinted(_to, _msgSender(), _qToken, _optionsAmount);
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
        nonReentrant()
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

        qTokenForCollateral.burn(_msgSender(), _optionsAmount);

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
            _msgSender(),
            collateralTokenId,
            _optionsAmount
        );

        qTokenToMint.mint(_msgSender(), _optionsAmount);

        emit SpreadMinted(
            _msgSender(),
            _qTokenToMint,
            _qTokenForCollateral,
            _optionsAmount
        );
    }

    function exercise(address _qToken, uint256 _amount)
        external
        override
        nonReentrant()
    {
        QToken qToken = QToken(_qToken);
        require(
            block.timestamp > qToken.expiryTime(),
            "Controller: Can not exercise options before their expiry"
        );

        uint256 amountToExercise;
        if (_amount == 0) {
            amountToExercise = qToken.balanceOf(_msgSender());
        } else {
            amountToExercise = _amount;
        }

        (bool isSettled, address payoutToken, uint256 payoutAmount) =
            getPayout(_qToken, amountToExercise);

        require(isSettled, "Controller: Cannot exercise unsettled options");

        qToken.burn(_msgSender(), amountToExercise);

        if (payoutAmount > 0) {
            IERC20(payoutToken).transfer(_msgSender(), payoutAmount);
        }

        emit OptionsExercised(
            _msgSender(),
            _qToken,
            amountToExercise,
            payoutAmount,
            payoutToken
        );
    }

    function claimCollateral(uint256 _collateralTokenId, uint256 _amount)
        external
        override
        nonReentrant()
    {
        (
            uint256 returnableCollateral,
            address collateralAsset,
            uint256 amountToClaim
        ) = calculateClaimableCollateral(_collateralTokenId, _amount);

        optionsFactory.collateralToken().burnCollateralToken(
            _msgSender(),
            _collateralTokenId,
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
            _collateralTokenId,
            amountToClaim,
            returnableCollateral,
            collateralAsset
        );
    }

    function neutralizePosition(uint256 _collateralTokenId, uint256 _amount)
        external
        override
        nonReentrant()
    {
        ICollateralToken collateralToken = optionsFactory.collateralToken();
        (address qTokenShort, address qTokenAsCollateral) =
            collateralToken.idToInfo(_collateralTokenId);

        //get the amount of collateral tokens owned
        uint256 collateralTokensOwned =
            collateralToken.balanceOf(_msgSender(), _collateralTokenId);

        //get the amount of qTokens owned
        uint256 qTokensOwned = QToken(qTokenShort).balanceOf(_msgSender());

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

        address collateralType;
        uint256 collateralOwed;

        {
            QuantMath.FixedPointInt memory collateralOwedFP;
            uint8 underlyingDecimals =
                OptionsUtils.getUnderlyingDecimals(
                    QToken(qTokenShort),
                    optionsFactory.quantConfig()
                );

            (collateralType, collateralOwedFP) = FundsCalculator
                .getCollateralRequirement(
                qTokenShort,
                address(0),
                amountToNeutralize,
                OPTIONS_DECIMALS,
                underlyingDecimals
            );

            collateralOwed = collateralOwedFP.toScaledUint(
                underlyingDecimals,
                true
            );
        }

        QToken(qTokenShort).burn(_msgSender(), amountToNeutralize);

        collateralToken.burnCollateralToken(
            _msgSender(),
            _collateralTokenId,
            amountToNeutralize
        );

        IERC20(collateralType).safeTransfer(_msgSender(), collateralOwed);

        //give the user their long tokens (if any)
        if (qTokenAsCollateral != address(0)) {
            QToken(qTokenAsCollateral).mint(_msgSender(), amountToNeutralize);
        }

        emit NeutralizePosition(
            _msgSender(),
            qTokenShort,
            amountToNeutralize,
            collateralOwed,
            collateralType,
            qTokenAsCollateral
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
                _msgSender(),
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

        IPriceRegistry.PriceWithDecimals memory expiryPrice =
            priceRegistry.getSettlementPriceWithDecimals(
                qTokenShort.oracle(),
                qTokenShort.underlyingAsset(),
                qTokenShort.expiryTime()
            );

        if (qTokenAsCollateral != address(0)) {
            qTokenLong = qTokenAsCollateral;

            (, payoutFromLong) = FundsCalculator.getPayout(
                qTokenLong,
                amountToClaim,
                OPTIONS_DECIMALS,
                expiryPrice
            );
        } else {
            qTokenLong = address(0);
            payoutFromLong = int256(0).fromUnscaledInt();
        }

        uint8 underlyingDecimals =
            OptionsUtils.getUnderlyingDecimals(
                qTokenShort,
                optionsFactory.quantConfig()
            );

        QuantMath.FixedPointInt memory collateralRequirement;
        (collateralAsset, collateralRequirement) = FundsCalculator
            .getCollateralRequirement(
            _qTokenShort,
            qTokenLong,
            amountToClaim,
            OPTIONS_DECIMALS,
            underlyingDecimals
        );

        (, QuantMath.FixedPointInt memory payoutFromShort) =
            FundsCalculator.getPayout(
                _qTokenShort,
                amountToClaim,
                OPTIONS_DECIMALS,
                expiryPrice
            );

        returnableCollateral = payoutFromLong
            .add(collateralRequirement)
            .sub(payoutFromShort)
            .toScaledUint(underlyingDecimals, true);
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
        QuantMath.FixedPointInt memory collateralAmountFP;
        uint8 underlyingDecimals =
            OptionsUtils.getUnderlyingDecimals(
                QToken(_qTokenToMint),
                optionsFactory.quantConfig()
            );

        (collateral, collateralAmountFP) = FundsCalculator
            .getCollateralRequirement(
            _qTokenToMint,
            _qTokenForCollateral,
            _optionsAmount,
            OPTIONS_DECIMALS,
            underlyingDecimals
        );

        collateralAmount = collateralAmountFP.toScaledUint(
            underlyingDecimals,
            false
        );
    }

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

        uint8 payoutDecimals =
            OptionsUtils.getUnderlyingDecimals(
                qToken,
                optionsFactory.quantConfig()
            );

        address underlyingAsset = QToken(_qToken).underlyingAsset();

        IPriceRegistry.PriceWithDecimals memory expiryPrice =
            priceRegistry.getSettlementPriceWithDecimals(
                QToken(_qToken).oracle(),
                underlyingAsset,
                QToken(_qToken).expiryTime()
            );

        (payoutToken, payout) = FundsCalculator.getPayout(
            _qToken,
            _amount,
            OPTIONS_DECIMALS,
            expiryPrice
        );

        payoutAmount = payout.toScaledUint(payoutDecimals, true);
    }
}
