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
   getCollateralRequirement(address _qTokenToMint,
                                      address _qTokenForCollateral,
                                      uint256 _optionsAmount,
                                      uint8 _optionsDecimals,
                                      uint8 _underlyingDecimals) returns (int256) envfree;

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
rule checkRule1(address qTokenToMint,
                uint256 optionsAmount,
                uint8 optionsDecimals,
                uint8 underlyingDecimals,
                address qTokenForCollateralNonZero) {

    // setting decimals to _BASE_DECIMALS = 27 to simplify FixedPointInt
    require optionsDecimals == 27;
    require underlyingDecimals == 27;

    // will set optionsAmount to have 10^27 decimal places;
    require optionsAmount >= 10^27;
    require optionsAmount < 10^28;

    // minting a spread
    require qTokenForCollateralNonZero != 0;
    int256 spreadCollateral = getCollateralRequirement(qTokenToMint,
                                                              qTokenForCollateralNonZero,
                                                              optionsAmount,
                                                              optionsDecimals,
                                                              underlyingDecimals);
    mathint MSpreadCollateral = SIGNED_INT_TO_MATHINT(spreadCollateral);

    // minting a non-spread option
    address qTokenForCollateralZero;
    require qTokenForCollateralZero == 0;
    int256 nonSpreadCollateral = getCollateralRequirement(qTokenToMint,
                                                                qTokenForCollateralZero,
                                                                optionsAmount,
                                                                optionsDecimals,
                                                                underlyingDecimals);
    mathint MNonSpreadCollateral = SIGNED_INT_TO_MATHINT(nonSpreadCollateral);

    assert MSpreadCollateral <= MNonSpreadCollateral;
}



////////////////////////////////////////////////////////////////////////////
//                       Helper Functions                                 //
////////////////////////////////////////////////////////////////////////////

