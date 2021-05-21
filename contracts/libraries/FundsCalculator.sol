// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma abicoder v2;

import "./QuantMath.sol";
import "../options/QToken.sol";

//TODO: Deployment scripts should deploy and link this
library FundsCalculator {
    using SafeMath for uint256;
    using QuantMath for uint256;
    using QuantMath for int256;
    using QuantMath for QuantMath.FixedPointInt;

    struct OptionPayoutInput {
        QuantMath.FixedPointInt strikePrice;
        QuantMath.FixedPointInt expiryPrice;
        QuantMath.FixedPointInt amount;
        QToken qToken;
    }

    function getPayout(
        address _qToken,
        uint256 _amount,
        uint256 _optionsDecimals,
        IPriceRegistry _priceRegistry,
        IAssetsRegistry _assetsRegistry
    )
        internal
        view
        returns (
            bool isSettled,
            address payoutToken,
            QuantMath.FixedPointInt memory payoutAmount,
            uint8 payoutDecimals
        )
    {
        QToken qToken = QToken(_qToken);
        isSettled = qToken.getOptionPriceStatus() == PriceStatus.SETTLED;
        if (!isSettled) {
            return (false, address(0), int256(0).fromUnscaledInt(), 0);
        }

        uint256 strikePrice = qToken.strikePrice();
        uint256 expiryPrice =
            _priceRegistry.getSettlementPrice(
                qToken.oracle(),
                qToken.underlyingAsset(),
                qToken.expiryTime()
            );

        FundsCalculator.OptionPayoutInput memory payoutInput =
            FundsCalculator.OptionPayoutInput(
                strikePrice.fromScaledUint(6),
                expiryPrice.fromScaledUint(6),
                _amount.fromScaledUint(_optionsDecimals),
                qToken
            );

        if (qToken.isCall()) {
            (, , uint8 underlyingDecimals, ) =
                _assetsRegistry.assetProperties(qToken.underlyingAsset());

            (payoutToken, payoutAmount) = getPayoutForCall(payoutInput);
            payoutDecimals = underlyingDecimals;
        } else {
            (payoutToken, payoutAmount) = getPayoutForPut(payoutInput);
            payoutDecimals = 6;
        }
    }

    function getPayoutForCall(
        FundsCalculator.OptionPayoutInput memory payoutInput
    )
        internal
        view
        returns (
            address payoutToken,
            QuantMath.FixedPointInt memory payoutAmount
        )
    {
        payoutAmount = payoutInput.expiryPrice.isGreaterThan(
            payoutInput.strikePrice
        )
            ? payoutInput
                .expiryPrice
                .sub(payoutInput.strikePrice)
                .mul(payoutInput.amount)
                .div(payoutInput.expiryPrice)
            : int256(0).fromUnscaledInt();
        payoutToken = payoutInput.qToken.underlyingAsset();
    }

    function getPayoutForPut(
        FundsCalculator.OptionPayoutInput memory payoutInput
    )
        internal
        view
        returns (
            address payoutToken,
            QuantMath.FixedPointInt memory payoutAmount
        )
    {
        payoutAmount = payoutInput.strikePrice.isGreaterThan(
            payoutInput.expiryPrice
        )
            ? (payoutInput.strikePrice.sub(payoutInput.expiryPrice)).mul(
                payoutInput.amount
            )
            : int256(0).fromUnscaledInt();

        payoutToken = payoutInput.qToken.strikeAsset();
    }

    function getCollateralRequirement(
        address _qTokenToMint,
        address _qTokenForCollateral,
        uint256 _optionsAmount,
        uint256 _optionsDecimals,
        IAssetsRegistry _assetsRegistry
    )
        internal
        view
        returns (
            address collateral,
            QuantMath.FixedPointInt memory collateralAmount,
            uint8 decimals
        )
    {
        QToken qTokenToMint = QToken(_qTokenToMint);
        uint256 qTokenToMintStrikePrice = qTokenToMint.strikePrice();

        uint256 qTokenForCollateralStrikePrice;
        if (_qTokenForCollateral != address(0)) {
            QToken qTokenForCollateral = QToken(_qTokenForCollateral);

            // Check that expiries match
            require(
                qTokenToMint.expiryTime() == qTokenForCollateral.expiryTime(),
                "Controller: Can't create spreads from options with different expiries"
            );

            // Check that the underlyings match
            require(
                qTokenToMint.underlyingAsset() ==
                    qTokenForCollateral.underlyingAsset(),
                "Controller: Can't create spreads from options with different underlying assets"
            );

            // Check that the option types match
            require(
                qTokenToMint.isCall() == qTokenForCollateral.isCall(),
                "Controller: Can't create spreads from options with different types"
            );

            // Check that the options have a matching oracle
            require(
                qTokenToMint.oracle() == qTokenForCollateral.oracle(),
                "Controller: Can't create spreads from options with different oracles"
            );

            qTokenForCollateralStrikePrice = qTokenForCollateral.strikePrice();
        }

        QuantMath.FixedPointInt memory collateralPerOption;
        if (qTokenToMint.isCall()) {
            collateral = qTokenToMint.underlyingAsset();

            // Initially required collateral is the long strike price
            (, , decimals, ) = _assetsRegistry.assetProperties(collateral);

            collateralPerOption = (10**decimals).fromScaledUint(decimals);

            if (_qTokenForCollateral != address(0)) {
                collateralPerOption = getCallSpreadCollateralRequirement(
                    qTokenToMintStrikePrice,
                    qTokenForCollateralStrikePrice
                );
            }
        } else {
            collateralPerOption = getPutCollateralRequirement(
                _qTokenForCollateral,
                qTokenToMintStrikePrice,
                qTokenForCollateralStrikePrice
            );

            collateral = qTokenToMint.strikeAsset();

            decimals = 6;
        }

        collateralAmount = _optionsAmount.fromScaledUint(_optionsDecimals).mul(
            collateralPerOption
        );
    }

    function getPutCollateralRequirement(
        address _qTokenForCollateral,
        uint256 _qTokenToMintStrikePrice,
        uint256 _qTokenForCollateralStrikePrice
    )
        internal
        pure
        returns (QuantMath.FixedPointInt memory collateralPerOption)
    {
        QuantMath.FixedPointInt memory mintStrikePrice =
            _qTokenToMintStrikePrice.fromScaledUint(6);
        QuantMath.FixedPointInt memory collateralStrikePrice =
            _qTokenForCollateralStrikePrice.fromScaledUint(6);

        // Initially required collateral is the long strike price
        collateralPerOption = mintStrikePrice;

        if (_qTokenForCollateral != address(0)) {
            collateralPerOption = getPutSpreadCollateralRequirement(
                mintStrikePrice,
                collateralStrikePrice
            );
        }
    }

    function getPutSpreadCollateralRequirement(
        QuantMath.FixedPointInt memory mintStrikePrice,
        QuantMath.FixedPointInt memory collateralStrikePrice
    ) internal pure returns (QuantMath.FixedPointInt memory) {
        return
            mintStrikePrice.isGreaterThan(collateralStrikePrice)
                ? mintStrikePrice.sub(collateralStrikePrice) // Put Credit Spread
                : int256(0).fromUnscaledInt(); // Put Debit Spread
    }

    function getCallSpreadCollateralRequirement(
        uint256 _qTokenToMintStrikePrice,
        uint256 _qTokenForCollateralStrikePrice
    ) internal pure returns (QuantMath.FixedPointInt memory) {
        QuantMath.FixedPointInt memory mintStrikePrice =
            _qTokenToMintStrikePrice.fromScaledUint(6);
        QuantMath.FixedPointInt memory collateralStrikePrice =
            _qTokenForCollateralStrikePrice.fromScaledUint(6);

        return
            mintStrikePrice.isGreaterThanOrEqual(collateralStrikePrice)
                ? int256(0).fromUnscaledInt() // Call Debit Spread
                : (mintStrikePrice.sub(collateralStrikePrice)).div(
                    collateralStrikePrice
                ); // Call Credit Spread
    }
}
