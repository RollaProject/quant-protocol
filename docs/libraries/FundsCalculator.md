## `FundsCalculator`






### `getPayout(address _qToken, uint256 _amount, uint256 _optionsDecimals, struct IPriceRegistry.PriceWithDecimals _expiryPrice) → address payoutToken, struct QuantMath.FixedPointInt payoutAmount` (internal)





### `getCollateralRequirement(address _qTokenToMint, address _qTokenForCollateral, uint256 _optionsAmount, uint8 _optionsDecimals, uint8 _underlyingDecimals) → address collateral, struct QuantMath.FixedPointInt collateralAmount` (internal)





### `getPayoutAmount(bool _isCall, uint256 _strikePrice, uint256 _amount, uint256 _optionsDecimals, struct IPriceRegistry.PriceWithDecimals _expiryPrice) → struct QuantMath.FixedPointInt payoutAmount` (internal)





### `getPayoutForCall(struct FundsCalculator.OptionPayoutInput payoutInput) → struct QuantMath.FixedPointInt payoutAmount` (internal)





### `getPayoutForPut(struct FundsCalculator.OptionPayoutInput payoutInput) → struct QuantMath.FixedPointInt payoutAmount` (internal)





### `getOptionCollateralRequirement(uint256 _qTokenToMintStrikePrice, uint256 _qTokenForCollateralStrikePrice, uint256 _optionsAmount, bool _qTokenToMintIsCall, uint8 _optionsDecimals, uint8 _underlyingDecimals) → struct QuantMath.FixedPointInt collateralAmount` (internal)





### `getPutCollateralRequirement(uint256 _qTokenToMintStrikePrice, uint256 _qTokenForCollateralStrikePrice) → struct QuantMath.FixedPointInt collateralPerOption` (internal)





### `getCallCollateralRequirement(uint256 _qTokenToMintStrikePrice, uint256 _qTokenForCollateralStrikePrice, uint8 _underlyingDecimals) → struct QuantMath.FixedPointInt collateralPerOption` (internal)






