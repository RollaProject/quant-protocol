/*
    This is a specification file for smart contract verification with the Certora prover.
    For more information, visit: https://www.certora.com/

    This file is run with spec/scripts/runQuantCalculator.sh
	Assumptions:
*/

/*
    Declaration of contracts used in the spec
*/
using DummyERC20A as erc20A
using DummyERC20A as erc20B
using QTokenA as qTokenA
using QTokenB as qTokenB
using CollateralTokenHarness as collateralToken
////////////////////////////////////////////////////////////////////////////
//                      Methods                                           //
////////////////////////////////////////////////////////////////////////////


/*
    Declaration of methods that are used in the rules.
    envfree indicate that the method is not dependent on the environment (msg.value, msg.sender).
    Methods that are not declared here are assumed to be dependent on env.
*/

methods {

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
	qTokenA.totalSupply() returns (uint256) envfree => DISPATCHER(true)
	transferFrom(address from, address to, uint256 amount) => DISPATCHER(true)
	transfer(address to, uint256 amount) => DISPATCHER(true)


	// OptionsFactory
	collateralToken() => NONDET
	quantConfig() => NONDET

	// FundsCalculator
    // Ghost function for division
    computeDivision(int256 c, int256 m) returns (int256) =>
        ghost_division(c, m)

    // Ghost function for multiplication
    computeMultiplication(int256 a, int256 b) returns (int256) =>
        ghost_multiplication(a, b)

	// CollateralToken
	mintCollateralToken(address,uint256,uint256) => DISPATCHER(true)
	burnCollateralToken(address,uint256,uint256) => DISPATCHER(true)
	//balanceOf(address, uint256) => DISPATCHER(true)
	idToInfo(uint256) => DISPATCHER(true)
	collateralToken.getCollateralTokenId(address p,address q) returns (uint256) envfree => ghost_collateral(p,q)
	collateralToken.getTokenSupplies(uint) returns (uint) envfree
	//getCollateralTokenInfoTokenAddress(uint256) returns (address)  => DISPATCHER(true)
    collateralToken.getCollateralTokenInfoTokenAddress(uint) returns (address) envfree
	collateralToken.getCollateralTokenInfoTokenAsCollateral(uint)returns (address) envfree
	collateralToken.balanceOf(address, uint256) returns (uint256) envfree => DISPATCHER(true)

}


////////////////////////////////////////////////////////////////////////////
//                       Ghost                                            //
////////////////////////////////////////////////////////////////////////////

// A ghost to represent the uniqueness of collateralTokenId for each pair of qTokens
ghost ghost_collateral(address , address) returns uint; 

ghost ghost_division(int256, int256) returns int256;

ghost ghost_multiplication(int256, int256) returns int256;


////////////////////////////////////////////////////////////////////////////
//                       Rules                                            //
////////////////////////////////////////////////////////////////////////////

// getExercisePayout, getCollateralRequirement, calculateClaimableCollateral
// return the same ERC20token for the same qtoken/collateralTokenID
/*
	Rule: Get Same Token
 	Description: getExercisePayout, getCollateralRequirement and calculateClaimableCollateral
 	             return the same ERC20token for the same qtoken/collateralTokenID.
	Formula:
			collateral = getCollateralRequirement(qToken, qTokenForCollateral, amount) &&
			payoutToken = getExercisePayout(qToken, amount) &&
			collateralAsset = calculateClaimableCollateral(collateralTokenID, amount)  =>
			
			    collateral == payoutToken && payoutToken == colaterallAsset
*/
rule getSameToken(uint256 collateralTokenId, uint256 amount, address optionsFactory) {
    env e;

    address qToken;
    address qTokenForCollateral;
    setupQtokenCollateralTokenId(qToken, qTokenForCollateral, collateralTokenId);

	require qToken == qTokenA;

    // token from getCollateralRequirement
    address collateral;
    uint256 collateralAmount;

	collateral,
	collateralAmount = getCollateralRequirement(e, qToken, qTokenForCollateral, amount);

    // token from getExercisePayout
    bool isSettled;
    address payoutToken;
    uint256 payoutAmount;

    isSettled,
    payoutToken,
    payoutAmount = getExercisePayout(e, qToken, amount);

    // token from calculateClaimableCollateral
    uint256 returnableCollateral;
    address collateralAsset;
    uint256 amountToClaim;

    returnableCollateral,
    collateralAsset,
    amountToClaim = calculateClaimableCollateral(e, collateralTokenId, amount, e.msg.sender);

    assert collateral == payoutToken, "getCollateralRequirement and getExercisePayout return different ERC20 token";
    assert payoutToken == collateralAsset, "getExercisePayout and calculateClaimableCollateral return different ERC20 token";
}

////////////////////////////////////////////////////////////////////////////
//                       Helper Functions                                 //
////////////////////////////////////////////////////////////////////////////

// setup the connections between qTokens and collateralTokenID
function setupQtokenCollateralTokenId(address qToken, address qTokenForCollateral, uint collateralTokenId) {
	require qToken == collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId);
	require ghost_collateral(qToken,qTokenForCollateral) == collateralTokenId;
}