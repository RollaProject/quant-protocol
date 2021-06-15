/*
    Another file for fundsCalculator so as to run rules which timeout in the presence
    of ghost summaries.

    This is a specification file for smart contract verification with the Certora prover.
    For more information, visit: https://www.certora.com/

    This file is run with scripts/...
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
   setPayoutInput(uint256 _strikePrice,
                   uint256 _expiryPrice,
                   uint256 _amount,
                   uint8 _expiryDecimals,
                   uint8 _optionsDecimals) envfree;

   addPayoutForPut() envfree;
   totalPayoutForPut() returns (uint256) envfree;

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
   checkAeqB(int256 _a, int256 _b) returns (bool) envfree;
   checkAplusBeqC(int256 _a, int256 _b, int256 _c) returns (bool) envfree;

   	// QToken methods to be called with one of the tokens (DummyERC20*, DummyWeth)
   	mint(address account, uint256 amount) => DISPATCHER(true)
   	burn(address account, uint256 amount) => DISPATCHER(true)
    underlyingAsset() returns (address) => DISPATCHER(true)
   	strikeAsset() returns (address) => DISPATCHER(true)
   	strikePrice() returns (uint256) => DISPATCHER(true)
   	expiryTime() returns (uint256) => DISPATCHER(true)
   	isCall() returns (bool) => DISPATCHER(true)

    // IERC20 methods to be called with one of the tokens (DummyERC20A, DummyERC20A) or QToken
    balanceOf(address) => DISPATCHER(true)
    totalSupply() => DISPATCHER(true)
    transferFrom(address from, address to, uint256 amount) => DISPATCHER(true)
    transfer(address to, uint256 amount) => DISPATCHER(true)
}

////////////////////////////////////////////////////////////////////////////
//                       Ghost                                            //
////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////
//                       Invariants                                       //
////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////
//                       Rules                                            //
////////////////////////////////////////////////////////////////////////////


// Additive: getPayout(amount1) + getPayout(amount2) == getPayout(amount1 + amount2)
rule checkPayoutAmountAdditive(uint256 strikePrice,
                               uint256 expiryPrice,
                               uint256 amount1,
                               uint256 amount2) {


    uint8 expiryDecimals = 6;
    uint8 optionsDecimals = 18;

    setPayoutInput(strikePrice, expiryPrice, amount1, expiryDecimals, optionsDecimals);
    int256 payoutAmount1 = getPayoutForPutWrapper();

    setPayoutInput(strikePrice, expiryPrice, amount2, expiryDecimals, optionsDecimals);
    int256 payoutAmount2 = getPayoutForPutWrapper();

    setPayoutInput(strikePrice, expiryPrice, amount1 + amount2, expiryDecimals, optionsDecimals);
    int256 payoutAmount3 = getPayoutForPutWrapper();

    assert checkAplusBeqC(payoutAmount1, payoutAmount2, payoutAmount3);
}

////////////////////////////////////////////////////////////////////////////
//                       Helper Functions                                 //
////////////////////////////////////////////////////////////////////////////

