// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma abicoder v2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IQuantCalculator.sol";
import "./interfaces/IOptionsFactory.sol";
import "./interfaces/IQToken.sol";
import "./interfaces/IPriceRegistry.sol";
import "./libraries/FundsCalculator.sol";
import "./libraries/OptionsUtils.sol";
import "./libraries/QuantMath.sol";

contract QuantCalculator is IQuantCalculator {
    using SafeMath for uint256;
    using QuantMath for uint256;
    using QuantMath for int256;
    using QuantMath for QuantMath.FixedPointInt;

    uint8 public constant override OPTIONS_DECIMALS = 18;
    address public immutable override optionsFactory;

    modifier validQToken(address _qToken) {
        require(
            IOptionsFactory(optionsFactory).isQToken(_qToken),
            "QuantCalculator: Invalid QToken address"
        );

        _;
    }

    modifier validQTokenAsCollateral(address _qTokenAsCollateral) {
        if (_qTokenAsCollateral != address(0)) {
            // it could be the zero address for the qTokenAsCollateral for non-spreads
            require(
                IOptionsFactory(optionsFactory).isQToken(_qTokenAsCollateral),
                "QuantCalculator: Invalid QToken address"
            );
        }

        _;
    }

    constructor(address _optionsFactory) {
        optionsFactory = _optionsFactory;
    }

    //TODO: msgSender balanceOf should be moved to controller
    function calculateClaimableCollateral(
        uint256 _collateralTokenId,
        uint256 _amount,
        address _msgSender
    )
        external
        view
        override
        returns (
            uint256 returnableCollateral,
            address collateralAsset,
            uint256 amountToClaim
        )
    {
        (address _qTokenShort, address qTokenAsCollateral) =
            IOptionsFactory(optionsFactory).collateralToken().idToInfo(
                _collateralTokenId
            );

        require(
            _qTokenShort != address(0),
            "Can not claim collateral from non-existing option"
        );

        IQToken qTokenShort = IQToken(_qTokenShort);

        require(
            block.timestamp > qTokenShort.expiryTime(),
            "Can not claim collateral from options before their expiry"
        );
        require(
            qTokenShort.getOptionPriceStatus() == PriceStatus.SETTLED,
            "Can not claim collateral before option is settled"
        );

        amountToClaim = _amount == 0
            ? IOptionsFactory(optionsFactory).collateralToken().balanceOf(
                _msgSender,
                _collateralTokenId
            )
            : _amount;

        address qTokenLong;
        QuantMath.FixedPointInt memory payoutFromLong;

        IPriceRegistry priceRegistry =
            IPriceRegistry(
                IOptionsFactory(optionsFactory).quantConfig().protocolAddresses(
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

        uint8 payoutDecimals =
            OptionsUtils.getPayoutDecimals(
                qTokenShort,
                IOptionsFactory(optionsFactory).quantConfig()
            );

        QuantMath.FixedPointInt memory collateralRequirement;
        (collateralAsset, collateralRequirement) = FundsCalculator
            .getCollateralRequirement(
            _qTokenShort,
            qTokenLong,
            amountToClaim,
            OPTIONS_DECIMALS,
            payoutDecimals
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
            .toScaledUint(payoutDecimals, true);
    }

    function getNeutralizationPayout(
        address _qTokenShort,
        address _qTokenLong,
        uint256 _amountToNeutralize
    )
        external
        view
        override
        returns (address collateralType, uint256 collateralOwed)
    {
        uint8 payoutDecimals =
            OptionsUtils.getPayoutDecimals(
                IQToken(_qTokenShort),
                IOptionsFactory(optionsFactory).quantConfig()
            );

        QuantMath.FixedPointInt memory collateralOwedFP;
        (collateralType, collateralOwedFP) = FundsCalculator
            .getCollateralRequirement(
            _qTokenShort,
            _qTokenLong,
            _amountToNeutralize,
            OPTIONS_DECIMALS,
            payoutDecimals
        );

        collateralOwed = collateralOwedFP.toScaledUint(payoutDecimals, true);
    }

    function getCollateralRequirement(
        address _qTokenToMint,
        address _qTokenForCollateral,
        uint256 _amount
    )
        external
        view
        override
        validQToken(_qTokenToMint)
        validQTokenAsCollateral(_qTokenForCollateral)
        returns (address collateral, uint256 collateralAmount)
    {
        QuantMath.FixedPointInt memory collateralAmountFP;
        uint8 payoutDecimals =
            OptionsUtils.getPayoutDecimals(
                IQToken(_qTokenToMint),
                IOptionsFactory(optionsFactory).quantConfig()
            );

        (collateral, collateralAmountFP) = FundsCalculator
            .getCollateralRequirement(
            _qTokenToMint,
            _qTokenForCollateral,
            _amount,
            OPTIONS_DECIMALS,
            payoutDecimals
        );

        collateralAmount = collateralAmountFP.toScaledUint(
            payoutDecimals,
            false
        );
    }

    function getExercisePayout(address _qToken, uint256 _amount)
        external
        view
        override
        validQToken(_qToken)
        returns (
            bool isSettled,
            address payoutToken,
            uint256 payoutAmount
        )
    {
        IQToken qToken = IQToken(_qToken);
        isSettled = qToken.getOptionPriceStatus() == PriceStatus.SETTLED;
        if (!isSettled) {
            return (false, address(0), 0);
        } else {
            isSettled = true;
        }

        QuantMath.FixedPointInt memory payout;

        IPriceRegistry priceRegistry =
            IPriceRegistry(
                IOptionsFactory(optionsFactory).quantConfig().protocolAddresses(
                    ProtocolValue.encode("priceRegistry")
                )
            );

        uint8 payoutDecimals =
            OptionsUtils.getPayoutDecimals(
                qToken,
                IOptionsFactory(optionsFactory).quantConfig()
            );

        address underlyingAsset = qToken.underlyingAsset();

        IPriceRegistry.PriceWithDecimals memory expiryPrice =
            priceRegistry.getSettlementPriceWithDecimals(
                qToken.oracle(),
                underlyingAsset,
                qToken.expiryTime()
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
