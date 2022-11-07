// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "./options/CollateralToken.sol";
import "./interfaces/IQuantCalculator.sol";
import "./interfaces/IOptionsFactory.sol";
import "./interfaces/IQToken.sol";
import "./interfaces/IPriceRegistry.sol";
import "./libraries/FundsCalculator.sol";
import "./libraries/OptionsUtils.sol";
import "./libraries/QuantMath.sol";

/// @title For calculating collateral requirements and payouts for options and spreads
/// @author Rolla
/// @dev Uses fixed point arithmetic from the QuantMath library.
contract QuantCalculator is IQuantCalculator {
    using QuantMath for uint256;
    using QuantMath for int256;
    using QuantMath for QuantMath.FixedPointInt;

    /// @inheritdoc IQuantCalculator
    uint8 public immutable override optionsDecimals = OPTIONS_DECIMALS;

    /// @inheritdoc IQuantCalculator
    uint8 public immutable override strikeAssetDecimals = OptionsUtils.STRIKE_PRICE_DECIMALS;

    /// @inheritdoc IQuantCalculator
    address public immutable override optionsFactory;

    /// @inheritdoc IQuantCalculator
    address public immutable override assetsRegistry;

    /// @inheritdoc IQuantCalculator
    address public immutable override priceRegistry;

    /// @notice Checks that the QToken was created through the configured OptionsFactory
    modifier validQToken(address _qToken) {
        require(IOptionsFactory(optionsFactory).isQToken(_qToken), "QuantCalculator: Invalid QToken address");

        _;
    }

    /// @notice Checks that the QToken used as collateral for a spread is either the zero address
    /// or a QToken created through the configured OptionsFactory
    modifier validQTokenAsCollateral(address _qTokenAsCollateral) {
        if (_qTokenAsCollateral != address(0)) {
            // it could be the zero address for the qTokenAsCollateral for non-spreads
            require(
                IOptionsFactory(optionsFactory).isQToken(_qTokenAsCollateral), "QuantCalculator: Invalid QToken address"
            );
        }

        _;
    }

    /// @param _optionsFactory the address of the OptionsFactory contract
    /// @param _assetsRegistry the address of the AssetsRegistry contract
    /// @param _priceRegistry the address of the PriceRegistry contract
    constructor(address _optionsFactory, address _assetsRegistry, address _priceRegistry) {
        require(_optionsFactory != address(0), "QuantCalculator: invalid OptionsFactory address");
        require(_assetsRegistry != address(0), "QuantCalculator: invalid AssetsRegistry address");
        require(_priceRegistry != address(0), "QuantCalculator: invalid PriceRegistry address");

        optionsFactory = _optionsFactory;
        assetsRegistry = _assetsRegistry;
        priceRegistry = _priceRegistry;
    }

    /// @inheritdoc IQuantCalculator
    function calculateClaimableCollateral(uint256 _collateralTokenId, uint256 _amount, address _user)
        external
        view
        override
        returns (uint256 returnableCollateral, address collateralAsset, uint256 amountToClaim)
    {
        CollateralToken collateralToken = CollateralToken(IOptionsFactory(optionsFactory).collateralToken());

        (address _qTokenShort, address qTokenAsCollateral) = collateralToken.idToInfo(_collateralTokenId);

        IQToken qTokenShort = IQToken(_qTokenShort);
        address oracle = qTokenShort.oracle();
        uint88 expiryTime = qTokenShort.expiryTime();
        address underlyingAsset = qTokenShort.underlyingAsset();

        require(block.timestamp > qTokenShort.expiryTime(), "Can not claim collateral from options before their expiry");
        require(
            IPriceRegistry(priceRegistry).getOptionPriceStatus(oracle, expiryTime, underlyingAsset)
                == PriceStatus.SETTLED,
            "Can not claim collateral before option is settled"
        );

        amountToClaim = _amount == 0 ? collateralToken.balanceOf(_user, _collateralTokenId) : _amount;

        PriceWithDecimals memory expiryPrice =
            IPriceRegistry(priceRegistry).getSettlementPriceWithDecimals(oracle, expiryTime, underlyingAsset);

        address qTokenLong;
        QuantMath.FixedPointInt memory payoutFromLong;

        if (qTokenAsCollateral != address(0)) {
            qTokenLong = qTokenAsCollateral;

            (, payoutFromLong) =
                FundsCalculator.getPayout(qTokenLong, amountToClaim, optionsDecimals, strikeAssetDecimals, expiryPrice);
        } else {
            qTokenLong = address(0);
            payoutFromLong = int256(0).fromUnscaledInt();
        }

        uint8 payoutDecimals = OptionsUtils.getPayoutDecimals(qTokenShort, assetsRegistry);

        QuantMath.FixedPointInt memory collateralRequirement;
        (collateralAsset, collateralRequirement) = FundsCalculator.getCollateralRequirement(
            _qTokenShort, qTokenLong, amountToClaim, optionsDecimals, payoutDecimals, strikeAssetDecimals
        );

        (, QuantMath.FixedPointInt memory payoutFromShort) =
            FundsCalculator.getPayout(_qTokenShort, amountToClaim, optionsDecimals, strikeAssetDecimals, expiryPrice);

        returnableCollateral =
            payoutFromLong.add(collateralRequirement).sub(payoutFromShort).toScaledUint(payoutDecimals, true);
    }

    /// @inheritdoc IQuantCalculator
    function getNeutralizationPayout(address _qTokenShort, address _qTokenLong, uint256 _amountToNeutralize)
        external
        view
        override
        returns (address collateralType, uint256 collateralOwed)
    {
        uint8 payoutDecimals = OptionsUtils.getPayoutDecimals(IQToken(_qTokenShort), assetsRegistry);

        QuantMath.FixedPointInt memory collateralOwedFP;
        (collateralType, collateralOwedFP) = FundsCalculator.getCollateralRequirement(
            _qTokenShort, _qTokenLong, _amountToNeutralize, optionsDecimals, payoutDecimals, strikeAssetDecimals
        );

        collateralOwed = collateralOwedFP.toScaledUint(payoutDecimals, true);
    }

    /// @inheritdoc IQuantCalculator
    function getCollateralRequirement(address _qTokenToMint, address _qTokenForCollateral, uint256 _amount)
        external
        view
        override
        validQToken(_qTokenToMint)
        validQTokenAsCollateral(_qTokenForCollateral)
        returns (address collateral, uint256 collateralAmount)
    {
        QuantMath.FixedPointInt memory collateralAmountFP;
        uint8 payoutDecimals = OptionsUtils.getPayoutDecimals(IQToken(_qTokenToMint), assetsRegistry);

        (collateral, collateralAmountFP) = FundsCalculator.getCollateralRequirement(
            _qTokenToMint, _qTokenForCollateral, _amount, optionsDecimals, payoutDecimals, strikeAssetDecimals
        );

        collateralAmount = collateralAmountFP.toScaledUint(payoutDecimals, false);
    }

    /// @inheritdoc IQuantCalculator
    function getExercisePayout(address _qToken, uint256 _amount)
        external
        view
        override
        validQToken(_qToken)
        returns (bool isSettled, address payoutToken, uint256 payoutAmount)
    {
        IQToken qToken = IQToken(_qToken);
        address oracle = qToken.oracle();
        uint88 expiryTime = qToken.expiryTime();
        address underlyingAsset = qToken.underlyingAsset();

        isSettled = IPriceRegistry(priceRegistry).getOptionPriceStatus(oracle, expiryTime, underlyingAsset)
            == PriceStatus.SETTLED;
        if (!isSettled) {
            return (isSettled, payoutToken, payoutAmount);
        }

        QuantMath.FixedPointInt memory payout;

        uint8 payoutDecimals = OptionsUtils.getPayoutDecimals(qToken, assetsRegistry);

        PriceWithDecimals memory expiryPrice =
            IPriceRegistry(priceRegistry).getSettlementPriceWithDecimals(oracle, expiryTime, underlyingAsset);

        (payoutToken, payout) =
            FundsCalculator.getPayout(_qToken, _amount, optionsDecimals, strikeAssetDecimals, expiryPrice);

        payoutAmount = payout.toScaledUint(payoutDecimals, true);
    }
}
