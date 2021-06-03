// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma abicoder v2;

import "./QuantMath.sol";
import "./SignedConverter.sol";
import "../options/QToken.sol";
import "../interfaces/IPriceRegistry.sol";

//TODO: Deployment scripts should deploy and link this
library FundsCalculator {
    using SafeMath for uint256;
    using QuantMath for uint256;
    using QuantMath for int256;
    using QuantMath for QuantMath.FixedPointInt;
    using SignedConverter for uint256;
    using SignedConverter for int256;

    struct OptionPayoutInput {
        QuantMath.FixedPointInt strikePrice;
        QuantMath.FixedPointInt expiryPrice;
        QuantMath.FixedPointInt amount;
    }

    function getPayout(
        address _qToken,
        uint256 _amount,
        uint256 _optionsDecimals,
        IPriceRegistry.PriceWithDecimals memory _expiryPrice
    )
        internal
        view
        returns (
            address payoutToken,
            QuantMath.FixedPointInt memory payoutAmount
        )
    {
        QToken qToken = QToken(_qToken);
        bool isCall = qToken.isCall();

        payoutToken = isCall ? qToken.underlyingAsset() : qToken.strikeAsset();

        payoutAmount = getPayoutAmount(
            isCall,
            qToken.strikePrice(),
            _amount,
            _optionsDecimals,
            _expiryPrice
        );
    }

    function getCollateralRequirement(
        address _qTokenToMint,
        address _qTokenForCollateral,
        uint256 _optionsAmount,
        uint8 _optionsDecimals,
        uint8 _underlyingDecimals
    )
        internal
        view
        returns (
            address collateral,
            QuantMath.FixedPointInt memory collateralAmount
        )
    {
        QToken qTokenToMint = QToken(_qTokenToMint);
        uint256 qTokenToMintStrikePrice = qTokenToMint.strikePrice();

        uint256 qTokenForCollateralStrikePrice;

        if (_qTokenForCollateral != address(0)) {
            QToken qTokenForCollateral = QToken(_qTokenForCollateral);
            qTokenForCollateralStrikePrice = qTokenForCollateral.strikePrice();

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
        }

        collateralAmount = getOptionCollateralRequirement(
            qTokenToMintStrikePrice,
            qTokenForCollateralStrikePrice,
            _optionsAmount,
            qTokenToMint.isCall(),
            _optionsDecimals,
            _underlyingDecimals
        );

        collateral = qTokenToMint.isCall()
            ? qTokenToMint.underlyingAsset()
            : qTokenToMint.strikeAsset();
    }

    function getPayoutAmount(
        bool _isCall,
        uint256 _strikePrice,
        uint256 _amount,
        uint256 _optionsDecimals,
        IPriceRegistry.PriceWithDecimals memory _expiryPrice
    ) internal pure returns (QuantMath.FixedPointInt memory payoutAmount) {
        FundsCalculator.OptionPayoutInput memory payoutInput =
            FundsCalculator.OptionPayoutInput(
                _strikePrice.fromScaledUint(6),
                _expiryPrice.price.fromScaledUint(_expiryPrice.decimals),
                _amount.fromScaledUint(_optionsDecimals)
            );

        if (_isCall) {
            payoutAmount = getPayoutForCall(payoutInput);
        } else {
            payoutAmount = getPayoutForPut(payoutInput);
        }
    }

    function getPayoutForCall(
        FundsCalculator.OptionPayoutInput memory payoutInput
    ) internal pure returns (QuantMath.FixedPointInt memory payoutAmount) {
        payoutAmount = payoutInput.expiryPrice.isGreaterThan(
            payoutInput.strikePrice
        )
            ? payoutInput
                .expiryPrice
                .sub(payoutInput.strikePrice)
                .mul(payoutInput.amount)
                .div(payoutInput.expiryPrice)
            : int256(0).fromUnscaledInt();
    }

    function getPayoutForPut(
        FundsCalculator.OptionPayoutInput memory payoutInput
    ) internal pure returns (QuantMath.FixedPointInt memory payoutAmount) {
        payoutAmount = payoutInput.strikePrice.isGreaterThan(
            payoutInput.expiryPrice
        )
            ? (payoutInput.strikePrice.sub(payoutInput.expiryPrice)).mul(
                payoutInput.amount
            )
            : int256(0).fromUnscaledInt();
    }

    function getOptionCollateralRequirement(
        uint256 _qTokenToMintStrikePrice,
        uint256 _qTokenForCollateralStrikePrice,
        uint256 _optionsAmount,
        bool _qTokenToMintIsCall,
        uint8 _optionsDecimals,
        uint8 _underlyingDecimals
    ) internal pure returns (QuantMath.FixedPointInt memory collateralAmount) {
        QuantMath.FixedPointInt memory collateralPerOption;
        if (_qTokenToMintIsCall) {
            collateralPerOption = getCallCollateralRequirement(
                _qTokenToMintStrikePrice,
                _qTokenForCollateralStrikePrice,
                _underlyingDecimals
            );
        } else {
            collateralPerOption = getPutCollateralRequirement(
                _qTokenToMintStrikePrice,
                _qTokenForCollateralStrikePrice
            );
        }

        // set _optionsDecimals = _BASE_DECIMAL
//        collateralAmount = _optionsAmount.fromScaledUint(_optionsDecimals).mul(
//            collateralPerOption
//        );

        // since _optionsAmount has 27 decimal places, no need to scale
        collateralAmount = QuantMath.FixedPointInt(_optionsAmount.uintToInt()).mul(
            collateralPerOption
        );
    }

    function getPutCollateralRequirement(
        uint256 _qTokenToMintStrikePrice,
        uint256 _qTokenForCollateralStrikePrice
    )
        internal
        pure
        returns (QuantMath.FixedPointInt memory collateralPerOption)
    {
        QuantMath.FixedPointInt memory mintStrikePrice =
            //_qTokenToMintStrikePrice.fromScaledUint(6);
        QuantMath.FixedPointInt((_qTokenToMintStrikePrice.mul(10**21)).uintToInt());             // 21 = _BASE_DECIMAL - 6

        QuantMath.FixedPointInt memory collateralStrikePrice =
            //_qTokenForCollateralStrikePrice.fromScaledUint(6);
        QuantMath.FixedPointInt((_qTokenForCollateralStrikePrice.mul(10**21)).uintToInt());      // 21 = _BASE_DECIMAL - 6

        // Initially (non-spread) required collateral is the long strike price
        collateralPerOption = mintStrikePrice;

        if (_qTokenForCollateralStrikePrice > 0) {
            collateralPerOption = mintStrikePrice.isGreaterThan(
                collateralStrikePrice
            )
                ? mintStrikePrice.sub(collateralStrikePrice) // Put Credit Spread
                : int256(0).fromUnscaledInt(); // Put Debit Spread
        }
    }

    function getCallCollateralRequirement(
        uint256 _qTokenToMintStrikePrice,
        uint256 _qTokenForCollateralStrikePrice,
        uint8 _underlyingDecimals
    )
        internal
        pure
        returns (QuantMath.FixedPointInt memory collateralPerOption)
    {
        QuantMath.FixedPointInt memory mintStrikePrice =
//            _qTokenToMintStrikePrice.fromScaledUint(6);
        QuantMath.FixedPointInt((_qTokenToMintStrikePrice.mul(10**21)).uintToInt());             // 21 = _BASE_DECIMAL - 6

        QuantMath.FixedPointInt memory collateralStrikePrice =
//            _qTokenForCollateralStrikePrice.fromScaledUint(6);
        QuantMath.FixedPointInt((_qTokenForCollateralStrikePrice.mul(10**21)).uintToInt());      // 21 = _BASE_DECIMAL - 6

        // Initially (non-spread) required collateral is the long strike price
        // _underlyingDecimals = _BASE_DECIMAL
//        collateralPerOption = (10**_underlyingDecimals).fromScaledUint(
//            _underlyingDecimals
//        );
          collateralPerOption = QuantMath.FixedPointInt((10**_underlyingDecimals).uintToInt());

        if (_qTokenForCollateralStrikePrice > 0) {
            collateralPerOption = mintStrikePrice.isGreaterThanOrEqual(
                collateralStrikePrice
            )
                ? int256(0).fromUnscaledInt() // Call Debit Spread
                : (collateralStrikePrice.sub(mintStrikePrice)).div(
                    collateralStrikePrice
                ); // Call Credit Spread
        }
    }
}
