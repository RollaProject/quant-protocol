/*
    This is a specification file for smart contract verification with the Certora prover.
    For more information, visit: https://www.certora.com/

    This file is run with scripts/runFundsCalculator.sh
	Assumptions:
*/

using IEACAggregatorProxy as ieacAggregatorProxy


////////////////////////////////////////////////////////////////////////////
//                      Methods                                           //
////////////////////////////////////////////////////////////////////////////


/*
    Declaration of methods that are used in the rules.
    envfree indicate that the method is not dependent on the environment (msg.value, msg.sender).
    Methods that are not declared here are assumed to be dependent on env.
*/

methods {

    getExpiryPrice(
        address _aggregator,
        uint256 _expiryTimestamp,
        uint256 _roundIdAfterExpiry,
        uint256 _expiryRoundId
    ) returns (uint256, uint256) envfree;

    getAssetOracle(address _asset) returns (address) envfree;

    setExpiryPriceInRegistryByRound(
        address _asset,
        uint256 _expiryTimestamp,
        uint256 _roundIdAfterExpiry
    ) envfree;

    // setExpiryPriceInRegistry(
    //     address _asset,
    //     uint256 _expiryTimestamp,
    //     bytes memory
    // ) envfree;

    getAggregator(address) returns (address) envfree => DISPATCHER(true);

    ieacAggregatorProxy() => NONDET
    ieacAggregatorProxy.latestTimestamp() returns (uint256) envfree;
    ieacAggregatorProxy.latestRound() returns (uint256) envfree;
    ieacAggregatorProxy.getTimestamp(uint80) returns (uint256) => ghost_roundTimestamp(uint80);

}

////////////////////////////////////////////////////////////////////////////
//                       Ghost                                            //
////////////////////////////////////////////////////////////////////////////


// The axiom assumes monotonicity 
ghost ghost_roundTimestamp(uint80) returns uint {
    axiom forall uint80 roundId1. forall uint80 roundId2.
	roundId2 > roundId1 => ieacAggregatorProxy.getTimestamp(roundId2) >= ieacAggregatorProxy.getTimestamp(roundId1);
}

////////////////////////////////////////////////////////////////////////////
//                       Invariants                                       //
////////////////////////////////////////////////////////////////////////////

/* 	Rule: roundVsTimestamps
 	Description:  iff r1 < r2 < r3 < rN then t1 <= t2 <= t3 <= t4
	Formula: 	  For every {rX, rY} if X<Y then tX<tY
*/
invariant roundVsTimestamps(uint80 roundId1, uint80 roundId2)
    roundId2 > roundId1 && aggregator.getTimestamp(roundId2) >= aggregator.getTimestamp(roundId1)

/* 	Rule: assetOracle
 	Description:  asset oracle cannot be a null address
*/		
invariant assetOracle(address asset)
    getAssetOracle(asset) != 0


////////////////////////////////////////////////////////////////////////////
//                       General Rules                                   //
////////////////////////////////////////////////////////////////////////////

/* 	Rule: integrityOfSetExpiryPriceInRegistryByRound 
 	Description: Checks the integrity of setExpiryPriceInRegistryByRound
*/
rule integrityOfSetExpiryPriceInRegistryByRound (
        address _asset,
        uint256 _expiryTimestamp,
        uint256 _roundIdAfterExpiry) {
    requireInvariant assetOracle(asset);
    require _asset != 0;
    require _expiryTimestamp > 0;
    require _roundIdAfterExpiry >= 1;
	setExpiryPriceInRegistryByRound(_asset, _expiryTimestamp, _roundIdAfterExpiry);
    address assetOracle = getAssetOracle(_asset);

    // TODO: Check for this
    // IEACAggregatorProxy aggregator = IEACAggregatorProxy(assetOracle);
    address aggregator = getAggregator(assetOracle);

    // Get expiry round id from _roundIdAfterExpiry
    uint16 phaseOffset = 64; // constant phaseOffset value
    uint16 phaseId = to_uint16(_roundIdAfterExpiry >> phaseOffset);
    uint64 expiryRound = to_uint64(_roundIdAfterExpiry) - 1;
    uint80 expiryRoundId = to_uint80((to_uint256(phaseId) << phaseOffset) | expiryRound);

    // get expiry price for the expiryRoundId
    uint256 expiryPrice;
    uint256 expiryRoundId;
    expiryPrice, expiryRoundId = getExpiryPrice(
        assetOracle, // Should be of type IEACAggregatorProxy instead of address (ieacAggregatorProxy)?
        _expiryTimestamp,
        _roundIdAfterExpiry,
        _roundIdAfterExpiry - 1
    );
	assert expiryPrice>0, "Incorrect action of setExpiryPriceInRegistryByRound";
}

/* 	Rule: Valid chainlink manager oracle round rule  
 	Description:  searchRoundToSubmit for expiryTimestamp will always return the round rX corresponding to timestamp tX 
    such that tX is less than or equal to expiryTimestamp and there exists a r(X+1) such that t(X + 1) > expiryTimestamp
	Notes: 
*/
rule checkSearchRoundToSubmit(address _asset, uint256 _expiryTimestamp) {
    requireInvariant assetOracle(asset);
    
}

// TODO: Write rules for below
// require the asset is added to the active oracle

// require that aggregator.latestTimestamp() exists and is greater than or equal to 2
// require that the rounds aren't increased monotonically
// require