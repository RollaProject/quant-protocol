/*
    This is a specification file for smart contract verification with the Certora prover.
    For more information, visit: https://www.certora.com/

    This file is run with scripts/runFundsCalculator.sh
	Assumptions:
*/

using DummyERC20A as erc20A
using DummyERC20A as erc20B


////////////////////////////////////////////////////////////////////////////
//                      Methods                                           //
////////////////////////////////////////////////////////////////////////////


/*
    Declaration of methods that are used in the rules.
    envfree indicate that the method is not dependent on the environment (msg.value, msg.sender).
    Methods that are not declared here are assumed to be dependent on env.
*/

methods {
   getOptionCollateralRequirementWrapper(uint256 _qTokenToMintStrikePrice,
                                       uint256 _qTokenForCollateralStrikePrice,
                                       uint256 _optionsAmount,
                                       bool _qTokenToMintIsCall,
                                       uint8 _optionsDecimals,
                                       uint8 _underlyingDecimals) returns (int256) envfree;

   getPutCollateralRequirementWrapper(uint256 _qTokenToMintStrikePrice,
                                      uint256 _qTokenForCollateralStrikePrice) returns (int256) envfree;

   getCallCollateralRequirementWrapper(uint256 _qTokenToMintStrikePrice,
                                           uint256 _qTokenForCollateralStrikePrice,
                                           uint8 _underlyingDecimals) returns (int256) envfree;

   setPayoutInput(uint256 _strikePrice,
                   uint256 _expiryPrice,
                   uint256 _amount,
                   uint8 _expiryDecimals,
                   uint8 _optionsDecimals) envfree;

   getPayoutForPutWrapper() returns (int256) envfree;
   getPayoutForCallWrapper() returns (int256) envfree;
   getPayoutAmountWrapper(bool _isCall,
                               uint256 _strikePrice,
                               uint256 _expiryPrice,
                               uint256 _amount,
                               uint8 _optionsDecimals,
                               uint8 _expiryDecimals) returns (int256) envfree;

   checkAgeB(int256 _a, int256 _b) returns (bool) envfree;
   checkAleB(int256 _a, int256 _b) returns (bool) envfree;
   checkAplusBeqC(int256 _a, int256 _b, int256 _c) returns (bool) envfree;
   AsubB(int256 _a, int256 _b) returns (int256) envfree;
   uintToInt(uint256 x) returns (int256) envfree;

   	// QToken methods to be called with one of the tokens (DummyERC20*, DummyWeth)
   	mint(address account, uint256 amount) => DISPATCHER(true)
   	burn(address account, uint256 amount) => DISPATCHER(true)
    underlyingAsset() returns (address) => DISPATCHER(true)
   	strikeAsset() returns (address) => DISPATCHER(true)
   	strikePrice() returns (uint256) => DISPATCHER(true)
   	expiryTime() returns (uint256) => DISPATCHER(true)
   	isCall() returns (bool) => NONDET

   	// Ghost function for division
   	computeDivision(int256 c, int256 m) returns (int256) =>
   	    ghost_division(c, m)

    // Ghost function for multiplication
    computeMultiplication(int256 a, int256 b) returns (int256) =>
        ghost_multiplication(a, b)

    // IERC20 methods to be called with one of the tokens (DummyERC20A, DummyERC20A) or QToken
    balanceOf(address) => DISPATCHER(true)
    totalSupply() => DISPATCHER(true)
    transferFrom(address from, address to, uint256 amount) => DISPATCHER(true)
    transfer(address to, uint256 amount) => DISPATCHER(true)
}

////////////////////////////////////////////////////////////////////////////
//                       Ghost                                            //
////////////////////////////////////////////////////////////////////////////
ghost ghost_division(int256, int256) returns int256 {

    // only for comparing collateral and mint strike prices.
    axiom forall int256 c. forall int256 m.
        ghost_division(c, m) <= 1000000000000000000000000000;

    axiom forall int256 c. forall int256 m1. forall int256 m2.
        m1 > m2 => ghost_division(c, m1) <= ghost_division(c, m2);

    axiom forall int256 c1. forall int256 c2. forall int256 m.
        c1 > c2 => ghost_division(c1, m) >= ghost_division(c2, m);
}

ghost ghost_multiplication(int256, int256) returns int256;


////////////////////////////////////////////////////////////////////////////
//                       Invariants                                       //
////////////////////////////////////////////////////////////////////////////



////////////////////////////////////////////////////////////////////////////
//                       Rules                                            //
////////////////////////////////////////////////////////////////////////////

/*
	Rule: Spreads require less collateral than minting options
 	Description: Minting spreads (for both calls and puts) require same or less collateral than minting options.
	Formula:
			getOptionCollateralRequirement(qTokenToMintStrikePrice, qTokenForCollateralStrikePrice, optionsAmount)
                                           <=
            getOptionCollateralRequirement(qTokenToMintStrikePrice, 0, optionsAmount)
*/
rule checkOptionCollateralRequirement(uint256 qTokenToMintStrikePrice,
                                      uint256 qTokenForCollateralStrikePrice,
                                      uint256 optionsAmount,
                                      bool qTokenToMintIsCall,
                                      uint8 optionsDecimals,
                                      uint8 underlyingDecimals) {

   require underlyingDecimals == 6;
   require optionsDecimals == 18;

   // minting a non-spread option
   int256 optionCollateral = getOptionCollateralRequirementWrapper(qTokenToMintStrikePrice,
                                                            0,
                                                            optionsAmount,
                                                            qTokenToMintIsCall,
                                                            optionsDecimals,
                                                            underlyingDecimals);

   // minting a spread option (when qTokenForCollateralStrikePrice != 0)
   int256 spreadCollateral = getOptionCollateralRequirementWrapper(qTokenToMintStrikePrice,
                                                           qTokenForCollateralStrikePrice,
                                                           optionsAmount,
                                                           qTokenToMintIsCall,
                                                           optionsDecimals,
                                                           underlyingDecimals);

   // check spreads require less collateral than minting option : spreadCollateral <= optionCollateral
   assert checkAleB(spreadCollateral, optionCollateral);
}

/*
	Rule: Put collateral increases with decrease in collateral strike price
 	Description: Put spreads require same or more collateral as the collateral option token strike price decreases.
	Formula:
			collateralStrikePrice1 > collateralStrikePrice2 =>
			    getPutCollateralRequirement(mintStrikePrice, collateralStrikePrice2) >=
			    getPutCollateralRequirement(mintStrikePrice, collateralStrikePrice1)
*/
rule checkPutCollateralRequirement(uint256 mintStrikePrice,
                                    uint256 collateralStrikePrice1,
                                    uint256 collateralStrikePrice2) {

   // since we need to check the behavior as the collateralStrikePrice decreases
   require collateralStrikePrice1 > collateralStrikePrice2;

   int256 collateralRequirement1 = getPutCollateralRequirementWrapper(mintStrikePrice, collateralStrikePrice1);
   int256 collateralRequirement2 = getPutCollateralRequirementWrapper(mintStrikePrice, collateralStrikePrice2);

   // check collateralRequirement2 >= collateralRequirement1
   assert checkAgeB(collateralRequirement2, collateralRequirement1);
}

/*
	Rule: Put collateral decreases with decreases in mint strike price
 	Description: Put spreads require same or less collateral as the mint option token strike price decreases.
	Formula:
			mintStrikePrice1 > mintStrikePrice2 =>
			    getPutCollateralRequirement(mintStrikePrice2, collateralStrikePrice) <=
			    getPutCollateralRequirement(mintStrikePrice1, collateralStrikePrice)
*/
rule checkPutCollateralRequirement2(uint256 mintStrikePrice1,
                                    uint256 mintStrikePrice2,
                                    uint256 collateralStrikePrice) {

   // since we need to check the behaviour as the mintStrikePrice decreases
   require mintStrikePrice1 > mintStrikePrice2;

   int256 collateralRequirement1 = getPutCollateralRequirementWrapper(mintStrikePrice1, collateralStrikePrice);
   int256 collateralRequirement2 = getPutCollateralRequirementWrapper(mintStrikePrice2, collateralStrikePrice);

   // check less collateral required: collateralRequirement2 <= collateralRequirement1
   assert checkAleB(collateralRequirement2, collateralRequirement1);
}

/*
	Rule: Call spread collateral increases with increase in collateral strike price
 	Description: Call spreads require same or more collateral requirement as the collateral option token strike price increases.
	Formula:
			collateralStrikePrice1 > 0 &&
			collateralStrikePrice2 > 0 &&
			collateralStrikePrice1 < collateralStrikePrice2 =>
			    getCallCollateralRequirement(mintStrikePrice, collaterStrikePrice2) >=
			    getCallCollateralRequirement(mintStrikePrice, collateralStrikePrice1)

*/
rule checkCallCollateralRequirement(uint256 mintStrikePrice,
                                    uint256 collateralStrikePrice1,
                                    uint256 collateralStrikePrice2,
                                    uint8 underlyingDecimals) {

    require underlyingDecimals == 6;

    // since we are only concerned about call spreads, make
    // sure both collateral strike prices are greater than 0
    require collateralStrikePrice1 > 0;
    require collateralStrikePrice2 > 0;

    // since we need to check the behavior as the collateralStrikePrice increases
    require collateralStrikePrice1 < collateralStrikePrice2;

    int256 collateralRequirement1 = getCallCollateralRequirementWrapper(mintStrikePrice, collateralStrikePrice1,
                                                                            underlyingDecimals);
    int256 collateralRequirement2 = getCallCollateralRequirementWrapper(mintStrikePrice, collateralStrikePrice2,
                                                                            underlyingDecimals);

    // check more collateral required: collateralRequirement2 >= collateralRequirement1
    assert checkAgeB(collateralRequirement2, collateralRequirement1);
}

/*
	Rule: Call spread collateral decreases with increases in mint strike price
 	Description: Call spreads require same or less collateral requirement as the mint option strike price increases.
	Formula:
			mintStrikePrice1 < mintStrikePrice2 =>
                getCallCollateralRequirement(mintStrikePrice2, collateralStrikePrice) <=
                getCallCollateralRequirement(mintStrikePrice1, collateralStrikePrice)

*/
rule checkCallCollateralRequirement2(uint256 mintStrikePrice1,
                                    uint256 mintStrikePrice2,
                                    uint256 collateralStrikePrice,
                                    uint8 underlyingDecimals) {

    // since we need to check the behavior as the mintStrikePrice increases
    require mintStrikePrice1 < mintStrikePrice2;

    int256 collateralRequirement1 = getCallCollateralRequirementWrapper(mintStrikePrice1, collateralStrikePrice,
                                                                 underlyingDecimals);
    int256 collateralRequirement2 = getCallCollateralRequirementWrapper(mintStrikePrice2, collateralStrikePrice,
                                                                 underlyingDecimals);

    // check less collateral required: collateralRequirement2 <= collateralRequirement1
    assert checkAleB(collateralRequirement2, collateralRequirement1);
}


/*
	Rule: Positive Put Payout
 	Description: Payout for Puts is positive if and only if strike price is greater than expiry price and
 	             options amount is greater than 0.
	Formula:
			getPayoutForPut(strikePrice, expiryPrice, amount) > 0 <=>
			(strikePrice > expiryPrice) && (optionsAmount > 0)

*/
rule checkPayoutForPut(uint256 strikePrice,
                       uint256 expiryPrice,
                       uint256 amount,
                       uint8 expiryDecimals,
                       uint8 optionsDecimals) {

    require expiryDecimals == 6;
    require optionsDecimals == 18;

    setPayoutInput(strikePrice, expiryPrice, amount, expiryDecimals, optionsDecimals);

    // get scaled ints for above uints
    int256 strikePriceScaledInt = uintToInt(strikePrice * 1000000000000000000000);
    int256 expiryPriceScaledInt = uintToInt(expiryPrice * 1000000000000000000000);
    int256 amountScaledInt = uintToInt(amount * 1000000000);

    int256 a = AsubB(strikePriceScaledInt, expiryPriceScaledInt);
    require expiryPrice == strikePrice => a == 0;
    require ghost_multiplication(0, amountScaledInt) == 0;
    require ghost_multiplication(a, 0) == 0;
    require a > 0 && amount > 0 <=> ghost_multiplication(a, amountScaledInt) > 0;

    int256 payoutAmount = getPayoutForPutWrapper();

    assert payoutAmount > 0 <=> (strikePrice > expiryPrice) && (amount > 0);
}

/*
	Rule: Positive Call Payout
 	Description: If payout for a Call is positive, then expiry price must be greater than strike price and
 	             options amount must be positive.
	Formula:
			getPayoutForCall(strikePrice, expiryPrice, amount) > 0 =>
            (expiryPrice > strikePrice) && (optionsAmount > 0)

*/
rule checkPayoutForCall(uint256 strikePrice,
                       uint256 expiryPrice,
                       uint256 amount,
                       uint8 expiryDecimals,
                       uint8 optionsDecimals) {

    require expiryDecimals == 6;
    require optionsDecimals == 18;

    setPayoutInput(strikePrice, expiryPrice, amount, expiryDecimals, optionsDecimals);

    // get scaled ints for above uints
    int256 strikePriceScaledInt = uintToInt(strikePrice * 1000000000000000000000);
    int256 expiryPriceScaledInt = uintToInt(expiryPrice * 1000000000000000000000);
    int256 amountScaledInt = uintToInt(amount * 1000000000);

    int256 a = ghost_division(expiryPriceScaledInt, strikePriceScaledInt);
    require expiryPrice == strikePrice => a == 0;
    require ghost_multiplication(0, amountScaledInt) == 0;
    require ghost_multiplication(a, 0) == 0;

    int256 payoutAmount = getPayoutForCallWrapper();

    assert payoutAmount > 0 => (expiryPrice > strikePrice) && (amount > 0);
}

/*
	Rule: Zero Payout amount
 	Description: If expiry price is equal to strike price of an option or options amount is zero, the
 	             payout amount then is also zero.
	Formula:
			(expiryPrice == strikePrice) || (amount == 0) => getPayoutAmount(_isCall, strikePrice, expiryPrice, amount) == 0

*/
rule checkPayoutAmount(uint256 strikePrice,
                       uint256 expiryPrice,
                       uint256 amount,
                       uint8 optionsDecimals,
                       uint8 expiryDecimals,
                       bool _isCall) {

    require expiryDecimals == 6;
    require optionsDecimals == 18;

    int256 payoutAmount = getPayoutAmountWrapper(_isCall, strikePrice, expiryPrice, amount,
                                                 optionsDecimals, expiryDecimals);

    // get scaled ints for above uints
    int256 strikePriceScaledInt = uintToInt(strikePrice * 1000000000000000000000);
    int256 expiryPriceScaledInt = uintToInt(expiryPrice * 1000000000000000000000);
    int256 amountScaledInt = uintToInt(amount * 1000000000);

    int256 a = ghost_division(expiryPriceScaledInt, strikePriceScaledInt);
    require expiryPrice == strikePrice => a == 0;
    require ghost_multiplication(0, amountScaledInt) == 0;
    require forall int256 x. ghost_multiplication(x, 0) == 0;

    assert (expiryPrice == strikePrice) || (amount == 0) => payoutAmount == 0;
}

/*
	Rule: Additive Call Payout amount
 	Description: Payout amount for Call options follows additivity, i.e. PayoutAmount for amount1 + amount2 is
 	             equal to the sum of PayoutAmounts for amount1 and amount2.
	Formula:
			getPayoutforCall(strikePrice, expiryPrice, amount1) + getPayoutForCall(strikePrice, expiryPrice, amount2) ==
			getPayoutForCall(strikePrice, expiryPrice, amount1 + amount2)

*/
rule checkPayoutAmountAdditiveCall(uint256 strikePrice,
                                   uint256 expiryPrice,
                                   uint256 amount1,
                                   uint256 amount2) {

    uint8 expiryDecimals = 6;
    uint8 optionsDecimals = 18;

    require amount1 + amount2 < 2^255;
    uint256 amount3 = amount1 + amount2;

    setPayoutInput(strikePrice, expiryPrice, amount1, expiryDecimals, optionsDecimals);
    int256 payoutAmount1 = getPayoutForCallWrapper();

    setPayoutInput(strikePrice, expiryPrice, amount2, expiryDecimals, optionsDecimals);
    int256 payoutAmount2 = getPayoutForCallWrapper();

    // get scaled ints for above uints
    int256 strikePriceScaledInt = uintToInt(strikePrice * 1000000000000000000000);
    int256 expiryPriceScaledInt = uintToInt(expiryPrice * 1000000000000000000000);
    int256 amount1ScaledInt = uintToInt(amount1 * 1000000000);
    int256 amount2ScaledInt = uintToInt(amount2 * 1000000000);
    int256 amount3ScaledInt = uintToInt(amount3 * 1000000000);

    int256 a = ghost_division(expiryPriceScaledInt, strikePriceScaledInt);
    require ghost_multiplication(a, amount3ScaledInt) == ghost_multiplication(a, amount1ScaledInt) + ghost_multiplication(a, amount2ScaledInt);

    setPayoutInput(strikePrice, expiryPrice, amount3, expiryDecimals, optionsDecimals);
    int256 payoutAmount3 = getPayoutForCallWrapper();

    assert checkAplusBeqC(payoutAmount1, payoutAmount2, payoutAmount3);
}

/*
	Rule: Additive Put Payout amount
 	Description: Payout amount for Put options follows additivity, i.e. PayoutAmount for amount1 + amount2 is
 	             equal to the sum of PayoutAmounts for amount1 and amount2.
	Formula:
			getPayoutforPut(strikePrice, expiryPrice, amount1) + getPayoutforPut(strikePrice, expiryPrice, amount2) ==
			getPayoutforPut(strikePrice, expiryPrice, amount1 + amount2)

*/
rule checkPayoutAmountAdditivePut(uint256 strikePrice,
                                   uint256 expiryPrice,
                                   uint256 amount1,
                                   uint256 amount2) {

    uint8 expiryDecimals = 6;
    uint8 optionsDecimals = 18;

    require amount1 + amount2 < 2^255;
    uint256 amount3 = amount1 + amount2;

    setPayoutInput(strikePrice, expiryPrice, amount1, expiryDecimals, optionsDecimals);
    int256 payoutAmount1 = getPayoutForPutWrapper();

    setPayoutInput(strikePrice, expiryPrice, amount2, expiryDecimals, optionsDecimals);
    int256 payoutAmount2 = getPayoutForPutWrapper();

    // get scaled ints for above uints
    int256 strikePriceScaledInt = uintToInt(strikePrice * 1000000000000000000000);
    int256 expiryPriceScaledInt = uintToInt(expiryPrice * 1000000000000000000000);
    int256 amount1ScaledInt = uintToInt(amount1 * 1000000000);
    int256 amount2ScaledInt = uintToInt(amount2 * 1000000000);
    int256 amount3ScaledInt = uintToInt(amount3 * 1000000000);

    int256 a = AsubB(strikePriceScaledInt, expiryPriceScaledInt);
    require ghost_multiplication(a, amount3ScaledInt) == ghost_multiplication(a, amount1ScaledInt) + ghost_multiplication(a, amount2ScaledInt);

    setPayoutInput(strikePrice, expiryPrice, amount3, expiryDecimals, optionsDecimals);
    int256 payoutAmount3 = getPayoutForPutWrapper();

    assert checkAplusBeqC(payoutAmount1, payoutAmount2, payoutAmount3);
}



////////////////////////////////////////////////////////////////////////////
//                       Helper Functions                                 //
////////////////////////////////////////////////////////////////////////////

