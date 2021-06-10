pragma solidity ^0.7.0;
pragma abicoder v2;

import {FundsCalculator} from "../../contracts/libraries/FundsCalculator.sol";
import {QuantMath} from "../../contracts/libraries/QuantMath.sol";
import {SignedConverter} from "../../contracts/libraries/SignedConverter.sol";

contract FundsCalculatorWrapper {
    using QuantMath for uint256;
    using QuantMath for int256;
    using QuantMath for QuantMath.FixedPointInt;
    using SignedConverter for uint256;

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
    returns (int256 collateralPerOptionValue)
    {
        collateralAmount = FundsCalculator.getCallCollateralRequirement(
            _qTokenToMintStrikePrice,
            _qTokenForCollateralStrikePrice,
            _underlyingDecimals
        );

        collateralPerOptionValue = collateralAmount.value;
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
