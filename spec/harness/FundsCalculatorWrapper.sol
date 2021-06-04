pragma solidity ^0.7.0;
pragma abicoder v2;

import {FundsCalculator} from "../../contracts/libraries/FundsCalculator.sol";
import {QuantMath} from "../../contracts/libraries/QuantMath.sol";

contract FundsCalculatorWrapper {
    using QuantMath for QuantMath.FixedPointInt;

    QuantMath.FixedPointInt internal collateralAmount;

    function getCollateralRequirement(
        address _qTokenToMint,
        address _qTokenForCollateral,
        uint256 _optionsAmount,
        uint8 _optionsDecimals,
        uint8 _underlyingDecimals
    ) public returns (int256 collateralAmountInt) {
        address collateral;
        (collateral, collateralAmount) = FundsCalculator
            .getCollateralRequirement(
            _qTokenToMint,
            _qTokenForCollateral,
            _optionsAmount,
            _optionsDecimals,
            _underlyingDecimals
        );
        return collateralAmount.value;
    }

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

     function getCallCollateralRequirement(
         uint256 _qTokenToMintStrikePrice,
         uint256 _qTokenForCollateralStrikePrice,
         uint8 _underlyingDecimals
     )
     public
     returns (
        int256 collateralPerOptionValue
     ) {
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
}
