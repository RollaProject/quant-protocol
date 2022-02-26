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
//    getOptionCollateralRequirementWrapper(uint256 _qTokenToMintStrikePrice,
//                                        uint256 _qTokenForCollateralStrikePrice,
//                                        uint256 _optionsAmount,
//                                        bool _qTokenToMintIsCall,
//                                        uint8 _optionsDecimals,
//                                        uint8 _underlyingDecimals) returns (int256) envfree;

    setExpiryPriceInRegistryByRound(
        address _asset,
        uint256 _expiryTimestamp,
        uint256 _roundIdAfterExpiry
    ) envfree;

    setExpiryPriceInRegistry(
        address _asset,
        uint256 _expiryTimestamp,
        bytes memory
    ) envfree;

    setExpiryPriceInRegistryFallback(
        address _asset,
        uint256 _expiryTimestamp,
        uint256 _price
    ) envfree;

}


////////////////////////////////////////////////////////////////////////////
//                       Invariants                                       //
////////////////////////////////////////////////////////////////////////////

/* 	Rule: roundVsTimestamps
 	Description:  iff r1 < r2 < r3 < rN then t1 <= t2 <= t3 <= t4
	Formula: 	  For every {rX, rY} if X<Y then tX<tY
	Notes: 
*/
invariant roundVsTimestamps(uint80 roundId, uint256 timestamp, env e)
		qToken == collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId) &&
		qToken == qTokenA &&
		qToken != quantCalculator.qTokenToCollateralType(qToken) &&
		qToken != collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId)
		=> qTokenA.totalSupply() >= qTokenA.balanceOf(e.msg.sender)



////////////////////////////////////////////////////////////////////////////
//                       General Rules                                   //
////////////////////////////////////////////////////////////////////////////

/* 	Rule: Valid chainlink manager oracle round rule  
 	Description: searchRoundToSubmit for expiryTimestamp will always return the round rX corresponding to timestamp tX 
    such that tX is less than or equal to expiryTimestamp and there exists a r(X+1) such that t(X + 1) > expiryTimestamp
	Notes: 
*/

/// @notice Searches for the round in the asset oracle immediately after the expiry timestamp
/// @param _asset address of asset to search price for
/// @param _expiryTimestamp expiry timestamp to find the price at or before
/// @return the round id immediately after the timestamp submitted
function searchRoundToSubmit(address _asset, uint256 _expiryTimestamp)
    external
    view
    returns (uint80);

// require the asset is added to the registered oracle (optional)
// require that aggregator.latestTimestamp() exists and is greater than or equal to 2
// require that the rounds aren't increased monotonically