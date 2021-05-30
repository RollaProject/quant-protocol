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

    function calculateClaimableCollateral(
        uint256 _collateralTokenId,
        uint256 _amount,
        address _optionsFactory,
        address msgSender
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
        IOptionsFactory optionsFactory = IOptionsFactory(_optionsFactory);

        (address _qTokenShort, address qTokenAsCollateral) =
            optionsFactory.collateralToken().idToInfo(_collateralTokenId);

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
            ? optionsFactory.collateralToken().balanceOf(
                msgSender,
                _collateralTokenId
            )
            : _amount;

        address qTokenLong;
        QuantMath.FixedPointInt memory payoutFromLong;

        IPriceRegistry priceRegistry =
            IPriceRegistry(
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

        // if (payoutFromLong.sub(fee) > collateralRequirement.sub(payoutFromShort) {

        // } else {
        returnableCollateral = payoutFromLong
            .add(collateralRequirement)
            .sub(payoutFromShort)
            .toScaledUint(underlyingDecimals, true);
        // }
    }

    function getCollateralRequirement(
        address _qTokenToMint,
        address _qTokenForCollateral,
        address _optionsFactory,
        uint256 _amount
    )
        external
        view
        override
        returns (address collateral, uint256 collateralAmount)
    {
        IOptionsFactory optionsFactory = IOptionsFactory(_optionsFactory);

        QuantMath.FixedPointInt memory collateralAmountFP;
        uint8 underlyingDecimals =
            OptionsUtils.getUnderlyingDecimals(
                IQToken(_qTokenToMint),
                optionsFactory.quantConfig()
            );

        (collateral, collateralAmountFP) = FundsCalculator
            .getCollateralRequirement(
            _qTokenToMint,
            _qTokenForCollateral,
            _amount,
            OPTIONS_DECIMALS,
            underlyingDecimals
        );

        collateralAmount = collateralAmountFP.toScaledUint(
            underlyingDecimals,
            false
        );
    }

    function getPayout(
        address _qToken,
        address _optionsFactory,
        uint256 _amount
    )
        external
        view
        override
        returns (
            bool isSettled,
            address payoutToken,
            uint256 payoutAmount
        )
    {
        IOptionsFactory optionsFactory = IOptionsFactory(_optionsFactory);

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
                optionsFactory.quantConfig().protocolAddresses(
                    ProtocolValue.encode("priceRegistry")
                )
            );

        uint8 payoutDecimals =
            OptionsUtils.getUnderlyingDecimals(
                qToken,
                optionsFactory.quantConfig()
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