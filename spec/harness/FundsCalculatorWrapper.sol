pragma solidity ^0.7.0;
pragma abicoder v2;

import {FundsCalculator} from "../../contracts/libraries/FundsCalculator.sol";

contract FundCalculatorWrapper {
    using SafeMath for uint256;
    using QuantMath for uint256;
    using QuantMath for int256;
    using QuantMath for QuantMath.FixedPointInt;

    FundsCalculator.OptionPayoutInput internal payoutInput;

    function getPayout(
        address _qToken,
        uint256 _amount,
        uint256 _optionsDecimals,
        IPriceRegistry.PriceWithDecimals memory _expiryPrice
    )
    public
    view
    returns (
        address payoutToken,
        QuantMath.FixedPointInt memory payoutAmount
    ) {
        return FundsCalculator.getPayout(_qToken, _amount, _optionsDecimals, _expiryPrice);
    }

    function getCollateralRequirement(
        address _qTokenToMint,
        address _qTokenForCollateral,
        uint256 _optionsAmount,
        uint8 _optionsDecimals,
        uint8 _underlyingDecimals
    )
    public
    view
    returns (
        address collateral,
        QuantMath.FixedPointInt memory collateralAmount
    ) {
      return FundsCalculator.getCollateralRequirement(_qTokenToMint, _qTokenForCollateral, _optionsAmount,
                                                _optionsDecimals, _underlyingDecimals);
    }

    function getPayoutAmount(
        bool _isCall,
        uint256 _strikePrice,
        uint256 _amount,
        uint256 _optionsDecimals,
        IPriceRegistry.PriceWithDecimals memory _expiryPrice
    )
    public
    view
    returns (
        QuantMath.FixedPointInt memory payoutAmount
    ) {
        return FundsCalculator.getPayoutAmount(_isCall, _strikePrice, _amount, _optionsDecimals, _expiryPrice);
    }

    function getPayoutForCall()
    public
    view
    returns (
        QuantMath.FixedPointInt memory payoutAmount
    ) {
        return FundsCalculator.getPayoutForCall(payoutInput);
    }

    function getPayoutForPut()
    public
    view
    returns (
        QuantMath.FixedPointInt memory payoutAmount
    ) {
        return FundsCalculator.getPayoutForPut(payoutInput);
    }

    function getOptionCollateralRequirement(
        uint256 _qTokenToMintStrikePrice,
        uint256 _qTokenForCollateralStrikePrice,
        uint256 _optionsAmount,
        bool _qTokenToMintIsCall,
        uint8 _optionsDecimals,
        uint8 _underlyingDecimals
    )
    public
    view
    returns (
        QuantMath.FixedPointInt memory collateralAmount
    ) {
        return FundsCalculator.getOptionCollateralRequirement(_qTokenToMintStrikePrice,
                                                              _qTokenForCollateralStrikePrice,
                                                              _optionsAmount,
                                                              _qTokenToMintIsCall,
                                                              _optionsDecimals,
                                                              _underlyingDecimals);
    }

    function getPutCollateralRequirement(
        uint256 _qTokenToMintStrikePrice,
        uint256 _qTokenForCollateralStrikePrice
    )
    public
    view
    returns (
        QuantMath.FixedPointInt memory collateralPerOption
    ) {
        return FundsCalculator.getPutCollateralRequirement(_qTokenToMintStrikePrice, _qTokenForCollateralStrikePrice);
    }

    function getCallCollateralRequirement(
        uint256 _qTokenToMintStrikePrice,
        uint256 _qTokenForCollateralStrikePrice,
        uint8 _underlyingDecimals
    )
    public
    view
    returns (
        QuantMath.FixedPointInt memory collateralPerOption
    ) {
        return FundsCalculator.getCallCollateralRequirement(_qTokenToMintStrikePrice, _qTokenForCollateralStrikePrice,
                                                            _underlyingDecimals);
    }

}
