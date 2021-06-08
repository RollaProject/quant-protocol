/*
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
   getOptionCollateralRequirementWrapper(uint256 _qTokenToMintStrikePrice,
                                       uint256 _qTokenForCollateralStrikePrice,
                                       uint256 _optionsAmount,
                                       bool _qTokenToMintIsCall,
                                       uint8 _optionsDecimals,
                                       uint8 _underlyingDecimals) returns (int256) envfree;

   getPutCollateralRequirement(uint256 _qTokenToMintStrikePrice,
                               uint256 _qTokenForCollateralStrikePrice) returns (int256) envfree;

   getCallCollateralRequirementWrapper(uint256 _qTokenToMintStrikePrice,
                                           uint256 _qTokenForCollateralStrikePrice,
                                           uint8 _underlyingDecimals) returns (int256) envfree;

   checkAgeB(int256 _a, int256 _b) returns (bool) envfree;
   checkAleB(int256 _a, int256 _b) returns (bool) envfree;

   	// QToken methods to be called with one of the tokens (DummyERC20*, DummyWeth)
   	mint(address account, uint256 amount) => DISPATCHER(true)
   	burn(address account, uint256 amount) => DISPATCHER(true)
    underlyingAsset() returns (address) => DISPATCHER(true)
   	strikeAsset() returns (address) => DISPATCHER(true)
   	strikePrice() returns (uint256) => DISPATCHER(true)
   	expiryTime() returns (uint256) => DISPATCHER(true)
   	isCall() returns (bool) => ALWAYS(0)

   	// summary for getUnderlyingValue
   	getUnderlyingValue(uint8 _underlyingDecimals) returns (uint256) => ALWAYS(1000000000000000000000000000)

    // IERC20 methods to be called with one of the tokens (DummyERC20A, DummyERC20A) or QToken
    balanceOf(address) => DISPATCHER(true)
    totalSupply() => DISPATCHER(true)
    transferFrom(address from, address to, uint256 amount) => DISPATCHER(true)
    transfer(address to, uint256 amount) => DISPATCHER(true)
}

definition SIGNED_INT_TO_MATHINT(int256 x) returns mathint = x >= 2^255 ? x - 2^256 : x;


////////////////////////////////////////////////////////////////////////////
//                       Ghost                                            //
////////////////////////////////////////////////////////////////////////////



////////////////////////////////////////////////////////////////////////////
//                       Invariants                                       //
////////////////////////////////////////////////////////////////////////////



////////////////////////////////////////////////////////////////////////////
//                       Rules                                            //
////////////////////////////////////////////////////////////////////////////

// Rule 1 - spreads require less collateral than minting options
// checking internal function "getOptionCollateralRequirement"
rule checkOptionCollateralRequirement(uint256 qTokenToMintStrikePrice,
                                      uint256 qTokenForCollateralStrikePrice,
                                      uint256 optionsAmount,
                                      bool qTokenToMintIsCall,
                                      uint8 optionsDecimals,
                                      uint8 underlyingDecimals) {

   // since Strike Prices are USDCs, they have a decimal value of 6
   // i.e. there value can be from 0 to 999999
   require qTokenToMintStrikePrice < 10^6;
   require qTokenForCollateralStrikePrice < 10^6;

   // to have precise approximation and
   // to avoid division - set all decimals = Base decimals
   require underlyingDecimals == 27;
   require optionsDecimals == 27;

   // since optionsDecimals == 27, optionsAmount has to be less than 10^27
   require optionsAmount < 10^26;

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

// Rule 3 - Put spreads require more collateral
// as the collateral option token strike price decreases
rule checkPutCollateralRequirement(uint256 mintStrikePrice,
                                    uint256 collateralStrikePrice1,
                                    uint256 collateralStrikePrice2) {

   // since we need to check the behavior as the collateralStrikePrice decreases
   require collateralStrikePrice1 > collateralStrikePrice2;

   int256 collateralRequirement1 = getPutCollateralRequirement(mintStrikePrice, collateralStrikePrice1);
   int256 collateralRequirement2 = getPutCollateralRequirement(mintStrikePrice, collateralStrikePrice2);

   // check collateralRequirement2 >= collateralRequirement1
   assert checkAgeB(collateralRequirement2, collateralRequirement1);
}

// Rule 5 - Put spreads require less collateral
// as the mint option token strike price decreases
rule checkPutCollateralRequirement2(uint256 mintStrikePrice1,
                                    uint256 mintStrikePrice2,
                                    uint256 collateralStrikePrice) {

   // since Strike Prices are USDCs, they have a decimal value of 6
   // i.e. there value can be from 0 to 999999
   require mintStrikePrice1 < 10^6;
   require mintStrikePrice2 < 10^6;
   require collateralStrikePrice < 10^6;

   // since we need to check the behaviour as the mintStrikePrice decreases
   require mintStrikePrice1 > mintStrikePrice2;

   int256 collateralRequirement1 = getPutCollateralRequirement(mintStrikePrice1, collateralStrikePrice);
   int256 collateralRequirement2 = getPutCollateralRequirement(mintStrikePrice2, collateralStrikePrice);

   // check less collateral required: collateralRequirement2 <= collateralRequirement1
   assert checkAleB(collateralRequirement2, collateralRequirement1);
}

// Rule 2 - Call spreads require more collateral
// as the collateral option token strike price increases
rule checkCallCollateralRequirement(uint256 mintStrikePrice,
                                    uint256 collateralStrikePrice1,
                                    uint256 collateralStrikePrice2,
                                    uint8 underlyingDecimals) {

    // since Strike Prices are USDCs, they have a decimal value of 6
    // i.e. there value can be from 0 to 999999
    require mintStrikePrice < 10^6;
    require collateralStrikePrice1 < 10^6;
    require collateralStrikePrice2 < 10^6;

    // to have precise approximation and
    // to avoid division - set underlyingDecimals = Base decimals
    require underlyingDecimals == 27;

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

// Rule 4 - Call spreads require less collateral
// as the mint option strike price increases
rule checkCallCollateralRequirement2(uint256 mintStrikePrice1,
                                    uint256 mintStrikePrice2,
                                    uint256 collateralStrikePrice,
                                    uint8 underlyingDecimals) {

    // since Strike Prices are USDCs, they have a decimal value of 6
    // i.e. there value can be from 0 to 999999
    require mintStrikePrice1 < 10^6;
    require mintStrikePrice2 < 10^6;
    require collateralStrikePrice < 10^6;

    // since we need to check the behavior as the mintStrikePrice increases
    require mintStrikePrice1 < mintStrikePrice2;

    int256 collateralRequirement1 = getCallCollateralRequirementWrapper(mintStrikePrice1, collateralStrikePrice,
                                                                 underlyingDecimals);
    int256 collateralRequirement2 = getCallCollateralRequirementWrapper(mintStrikePrice2, collateralStrikePrice,
                                                                 underlyingDecimals);

    // check less collateral required: collateralRequirement2 <= collateralRequirement1
    assert checkAleB(collateralRequirement2, collateralRequirement1);

}


////////////////////////////////////////////////////////////////////////////
//                       Helper Functions                                 //
////////////////////////////////////////////////////////////////////////////

