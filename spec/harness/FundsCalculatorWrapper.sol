pragma solidity ^0.7.0;
pragma abicoder v2;

import {FundsCalculator} from "../../contracts/libraries/FundsCalculator.sol";
import {QuantMath} from "../../contracts/libraries/QuantMath.sol";

contract FundsCalculatorWrapper {
    using QuantMath for uint256;
    using QuantMath for int256;
    using QuantMath for QuantMath.FixedPointInt;

    QuantMath.FixedPointInt internal collateralAmount;

    // Rule 1
    function getOptionCollateralRequirementWrapper(
        uint256 _qTokenToMintStrikePrice,
        uint256 _qTokenForCollateralStrikePrice,
        uint256 _optionsAmount,
        bool _qTokenToMintIsCall,
        uint8 _optionsDecimals,
        uint8 _underlyingDecimals
    ) public returns (int256 collateralAmountValue) {
        QuantMath.FixedPointInt memory collateralPerOption;

        if (_qTokenToMintIsCall) {
           int256 _collateralPerOption = getCallCollateralRequirementWrapper(              //  --- calling Call Collateral Wrapper below
                _qTokenToMintStrikePrice,
                _qTokenForCollateralStrikePrice,
                _underlyingDecimals
            );
           collateralPerOption.value = _collateralPerOption;
        } else {
            collateralPerOption = FundsCalculator.getPutCollateralRequirement(
                _qTokenToMintStrikePrice,
                _qTokenForCollateralStrikePrice
            );
        }

        collateralAmount = _optionsAmount.fromScaledUint(_optionsDecimals).mul(
            collateralPerOption
        );
        collateralAmountValue = collateralAmount.value;
    }

    // Rule 3 and 5
    function getPutCollateralRequirement(
        uint256 _qTokenToMintStrikePrice,
        uint256 _qTokenForCollateralStrikePrice
    )
    public
    returns (
        int256 collateralPerOptionValue
    ) {
        collateralAmount = FundsCalculator.getPutCollateralRequirement(
            _qTokenToMintStrikePrice,
            _qTokenForCollateralStrikePrice
        );

        collateralPerOptionValue = collateralAmount.value;
    }

    // Rule 2 and 4
    function getCallCollateralRequirementWrapper(
        uint256 _qTokenToMintStrikePrice,
        uint256 _qTokenForCollateralStrikePrice,
        uint8 _underlyingDecimals
    )
    public
    returns (int256 collateralValue)
    {
        QuantMath.FixedPointInt memory mintStrikePrice =
        _qTokenToMintStrikePrice.fromScaledUint(6);
        QuantMath.FixedPointInt memory collateralStrikePrice =
        _qTokenForCollateralStrikePrice.fromScaledUint(6);

        // Initially (non-spread) required collateral is the long strike price
        uint256 _collateralAmount = getUnderlyingValue(_underlyingDecimals);            // --- simply get the underlying constant - 10^27 (don't do the exponentiation - see summary)
        collateralAmount = _collateralAmount.fromScaledUint(_underlyingDecimals);

        if (_qTokenForCollateralStrikePrice > 0) {
            collateralAmount = mintStrikePrice.isGreaterThanOrEqual(
                collateralStrikePrice
            )
            ? int256(0).fromUnscaledInt() // Call Debit Spread
            : (collateralStrikePrice.sub(mintStrikePrice)); // Call Credit Spread       --- NO DIV here by collateralStrikePrice
        }

        collateralValue = collateralAmount.value;
    }

    ////////////////////////////////////////////////////////////////
    //                  Helper Functions                          //
    ////////////////////////////////////////////////////////////////
    function checkAgeB(int256 _a, int256 _b) public returns (bool){
        return _a >= _b;
    }

    function checkAleB(int256 _a, int256 _b) public returns (bool) {
        return _a <= _b;
    }

    function getUnderlyingValue(uint8 _underlyingDecimals)
    internal pure returns (uint256 collateralPerOption) {
        collateralPerOption = (10**_underlyingDecimals);     // 10^27 == 10**_underlyingDecimals
    }
}
