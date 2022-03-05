pragma solidity 0.8.12;

import {FundsCalculator} from "../../contracts/libraries/FundsCalculator.sol";
import {QuantMath} from "../../contracts/libraries/QuantMath.sol";
import {SignedConverter} from "../../contracts/libraries/SignedConverter.sol";
import {IPriceRegistry} from "../../contracts/interfaces/IPriceRegistry.sol";

contract FundsCalculatorWrapper {
    using QuantMath for uint256;
    using QuantMath for int256;
    using QuantMath for QuantMath.FixedPointInt;
    using SignedConverter for uint256;

    QuantMath.FixedPointInt internal collateralAmount;
    FundsCalculator.OptionPayoutInput internal payoutInput;

    uint256 private constant _BASE_DECIMALS = 27;

    function setPayoutInput(
        uint256 _strikePrice,
        uint256 _expiryPrice,
        uint256 _amount,
        uint8 _expiryDecimals,
        uint8 _optionsDecimals,
        uint8 _strikeAssetDecimals
    ) public {
        payoutInput = FundsCalculator.OptionPayoutInput(
            _strikePrice.fromScaledUint(_strikeAssetDecimals),
            _expiryPrice.fromScaledUint(_expiryDecimals),
            _amount.fromScaledUint(_optionsDecimals)
        );
    }

    // Rule 1
    function getOptionCollateralRequirementWrapper(
        uint256 _qTokenToMintStrikePrice,
        uint256 _qTokenForCollateralStrikePrice,
        uint256 _optionsAmount,
        bool _qTokenToMintIsCall,
        uint8 _optionsDecimals,
        uint8 _underlyingDecimals,
        uint8 _strikeAssetDecimals
    ) public returns (int256 collateralAmountValue) {
        collateralAmount = FundsCalculator.getOptionCollateralRequirement(
            _qTokenToMintStrikePrice,
            _qTokenForCollateralStrikePrice,
            _optionsAmount,
            _qTokenToMintIsCall,
            _optionsDecimals,
            _underlyingDecimals,
            _strikeAssetDecimals
        );

        collateralAmountValue = collateralAmount.value;
    }

    // Rule 3 and 5
    function getPutCollateralRequirementWrapper(
        uint256 _qTokenToMintStrikePrice,
        uint256 _qTokenForCollateralStrikePrice,
        uint8 _strikeAssetDecimals
    ) public returns (int256 collateralPerOptionValue) {
        collateralAmount = FundsCalculator.getPutCollateralRequirement(
            _qTokenToMintStrikePrice,
            _qTokenForCollateralStrikePrice,
            _strikeAssetDecimals
        );

        collateralPerOptionValue = collateralAmount.value;
    }

    // Rule 2 and 4
    function getCallCollateralRequirementWrapper(
        uint256 _qTokenToMintStrikePrice,
        uint256 _qTokenForCollateralStrikePrice,
        uint8 _underlyingDecimals,
        uint8 _strikeAssetDecimals
    ) public returns (int256 collateralPerOptionValue) {
        collateralAmount = FundsCalculator.getCallCollateralRequirement(
            _qTokenToMintStrikePrice,
            _qTokenForCollateralStrikePrice,
            _underlyingDecimals,
            _strikeAssetDecimals
        );

        collateralPerOptionValue = collateralAmount.value;
    }

    function getPayoutForPutWrapper() public returns (int256 payoutAmount) {
        QuantMath.FixedPointInt memory payoutAmountStruct = FundsCalculator
            .getPayoutForPut(payoutInput);
        payoutAmount = payoutAmountStruct.value;
    }

    function getPayoutForCallWrapper() public returns (int256 payoutAmount) {
        QuantMath.FixedPointInt memory payoutAmountStruct = FundsCalculator
            .getPayoutForCall(payoutInput);
        payoutAmount = payoutAmountStruct.value;
    }

    function getPayoutAmountWrapper(
        bool _isCall,
        uint256 _strikePrice,
        uint256 _expiryPrice,
        uint256 _amount,
        uint8 _optionsDecimals,
        uint8 _strikeAssetDecimals,
        uint8 _expiryDecimals
    ) public returns (int256 payoutAmount) {
        QuantMath.FixedPointInt memory payoutAmountStruct;
        IPriceRegistry.PriceWithDecimals memory expiryPrice = IPriceRegistry
            .PriceWithDecimals(_expiryPrice, _expiryDecimals);

        payoutAmountStruct = FundsCalculator.getPayoutAmount(
            _isCall,
            _strikePrice,
            _amount,
            _optionsDecimals,
            _strikeAssetDecimals,
            expiryPrice
        );

        payoutAmount = payoutAmountStruct.value;
    }

    ////////////////////////////////////////////////////////////////
    //                  Helper Functions                          //
    ////////////////////////////////////////////////////////////////
    function checkAgeB(int256 _a, int256 _b) public returns (bool) {
        return _a >= _b;
    }

    function checkAleB(int256 _a, int256 _b) public returns (bool) {
        return _a <= _b;
    }

    function checkAplusBeqC(
        int256 _a,
        int256 _b,
        int256 _c
    ) public returns (bool) {
        return _c == _a + _b;
    }

    function uintToInt(uint256 a) public returns (int256) {
        require(a < 2**255, "FundsCalculatorWrapper: out of int range");

        return int256(a);
    }

    function AsubB(int256 _a, int256 _b) public returns (int256) {
        return _a - _b;
    }
}
