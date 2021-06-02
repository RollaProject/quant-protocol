/*
    This is a specification file for smart contract verification with the Certora prover.
    For more information, visit: https://www.certora.com/

    This file is run with scripts/...
	Assumptions:
*/


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
                                  uint8 _underlyingDecimals) returns (uint256) envfree;
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
rule checkRule1() {
    address qTokenToMint;
    uint256 optionsAmount;
    uint8 optionsDecimals;
    uint8 underlyingDecimals;

    // minting a spread
    address qTokenForCollateralNonZero;
    require qTokenForCollateralNonZero != 0;

    uint256 spreadCollateral = getCollateralRequirement(qTokenToMint,
                                                              qTokenForCollateralNonZero,
                                                              optionsAmount,
                                                              optionsDecimals,
                                                              underlyingDecimals);

    // minting a non-spread option
    address qTokenForCollateralZero;
    require qTokenForCollateralZero == 0;
    uint256 nonSpreadCollateral = getCollateralRequirement(qTokenToMint,
                                                                qTokenForCollateralZero,
                                                                optionsAmount,
                                                                optionsDecimals,
                                                                underlyingDecimals);

    assert spreadCollateral <= nonSpreadCollateral;
}



////////////////////////////////////////////////////////////////////////////
//                       Helper Functions                                 //
////////////////////////////////////////////////////////////////////////////

