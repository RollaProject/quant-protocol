/*
    This is a specification file for smart contract verification with the Certora prover.
    For more information, visit: https://www.certora.com/

    This file is run with scripts/...
	Assumptions: 
*/

/*
    Declaration of contracts used in the spec 
*/
using DummyERC20A as erc20A
using DummyERC20A as erc20B
using QTokenA as qTokenA
using QTokenB as qTokenB
using OptionsFactory as optionsFactory
using CollateralTokenHarness as collateralToken
using QuantCalculatorHarness as quantCalculator
////////////////////////////////////////////////////////////////////////////
//                      Methods                                           //
////////////////////////////////////////////////////////////////////////////


/*
    Declaration of methods that are used in the rules.
    envfree indicate that the method is not dependent on the environment (msg.value, msg.sender).
    Methods that are not declared here are assumed to be dependent on env.
*/

methods {
	    

	isValidQToken(address qToken) returns (bool) envfree

	// QToken methods to be called with one of the tokens (DummyERC20*, DummyWeth)	
	mint(address account, uint256 amount) => DISPATCHER(true)
	burn(address account, uint256 amount) => DISPATCHER(true)
    underlyingAsset() returns (address) => DISPATCHER(true)
	strikeAsset() returns (address) => DISPATCHER(true)
	strikePrice() returns (uint256) => DISPATCHER(true)
	expiryTime() returns (uint256) => DISPATCHER(true)	
	isCall() returns (bool) => DISPATCHER(true)


	// IERC20 methods to be called with one of the tokens (DummyERC20A, DummyERC20A) or QToken
	qTokenA.balanceOf(address) returns (uint256) envfree => DISPATCHER(true) 
	qTokenA.totalSupply() returns (uint256) envfree => DISPATCHER(true)
	transferFrom(address from, address to, uint256 amount) => DISPATCHER(true)
	transfer(address to, uint256 amount) => DISPATCHER(true)


	// OptionsFactory
	optionsFactory.isQToken(address _qToken) returns (bool) envfree => DISPATCHER(true)
	collateralToken() => NONDET
	quantConfig() => NONDET
	
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
	createCollateralToken(address,address) => NONDET
	
	
	// Computations
	getNeutralizationPayout(address,address,uint256,address) => NONDET 
	
	quantCalculator.qTokenToCollateralType(address) returns (address) envfree
	
	quantCalculator.claimableCollateral(uint256 collateralTokenId,
        uint256 amount
	) returns (uint256) envfree

	quantCalculator.getClaimableCollateralValue(uint256 collateralTokenId,
        uint256 amount
	) returns (uint256) envfree => ghost_claimableCollateral(collateralTokenId,amount) 

	quantCalculator.getCollateralRequirementValue(
        address qTokenToMint,
        address qTokenForCollateral,
        uint256 amount
    ) returns (uint256) envfree => ghost_collateralRequirement(qTokenToMint,qTokenForCollateral,amount) 

	quantCalculator.collateralRequirement(
        address qTokenToMint,
        address qTokenForCollateral,
        uint256 amount
    ) returns (uint256) envfree 


	quantCalculator.getExercisePayoutValue(
		address qToken,
		uint amount
	) returns (uint256) envfree => ghost_exercisePayout(qToken,amount) 

	quantCalculator.exercisePayout(
		address qToken,
		uint amount
	) returns (uint256) envfree 


	//ERC1155Receiver
	onERC1155Received(address,address,uint256,uint256,bytes) => NONDET

}



////////////////////////////////////////////////////////////////////////////
//                       Ghost                                            //
////////////////////////////////////////////////////////////////////////////


// Ghosts are like additional function

// A ghost to represent the uniqueness of collateralTokenId for each pair of qTokens
ghost ghost_collateral(address , address) returns uint; //`{
	//uniqueness
	//axiom forall uint256 p1. forall uint256 q1. forall uint256 p2. forall uint256 q2.
    //     (p1 != p2 || q1 != q2)  => ghost_collateral(p1,q1) != ghost_collateral(p2,q2);
//}


/***
A Set of ghosts to represent the connection between the collateral require to some amount of X tokens
and the amount of collateral that can be claimed and the execerse payout for those X tokens

claimableCollateral() ==  collateralRequirement() + exercisePayout()

***/

// A ghost to represent the amount of claimableCollateral per collateralId and amount
ghost ghost_claimableCollateral(uint256, uint256) returns uint;// {
	// additive
//	axiom forall uint256 cID. forall uint256 x. forall uint256 y. forall uint256 xPlusY. 
  //      xPlusY == x + y => ghost_claimableCollateral(cID,xPlusY) == ghost_claimableCollateral(cID,x) + ghost_claimableCollateral(cID, y);
//}

// A ghost to represent the amount of claimableCollateral per collateralId and amount
ghost ghost_collateralRequirement(address, address, uint256) returns uint;// {
	// additive
//	axiom forall address q1. forall address q2. forall uint256 x. forall uint256 y. forall uint256 xPlusY.
  //       xPlusY == x + y => ghost_collateralRequirement(q1, q2, xPlusY) == ghost_collateralRequirement(q1, q2, x) + /ghost_collateralRequirement(q1, q2, y);
//}

ghost ghost_exercisePayout(address, uint256) returns uint;// {
	// additive
//	axiom forall address q. forall uint256 x. forall uint256 y. forall uint256 xPlusY.
  //       xPlusY == x + y => ghost_exercisePayout(q, xPlusY) == ghost_exercisePayout(q, x) + ghost_exercisePayout(q, y);

//}

////////////////////////////////////////////////////////////////////////////
//                       Invariants                                       //
////////////////////////////////////////////////////////////////////////////



/* 	Rule: title  
 	Description:  
	Formula: 
	Notes: assumptions and simplification more explanations 
*/




////////////////////////////////////////////////////////////////////////////
//                       Rules                                            //
////////////////////////////////////////////////////////////////////////////
    
/* 	Rule: Valid QToken  
 	Description:  only valid QToken can be used in the state changing balances 
	Formula: 
	Notes: 
*/
rule validQtoken(method f)  
{
	address qToken; 
	address qTokenForCollateral;
	uint256 collateralTokenId;
	address to;
	uint256 amount;
	require qToken == qTokenA;
	// we need to assume that changes through collateralId are on valid qToken
	require qToken != collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId);
	require qToken != collateralToken.getCollateralTokenInfoTokenAsCollateral(collateralTokenId);
	// some functions do not take qToken as input so there is no check
	uint256 totalSupplyBefore = qTokenA.totalSupply();
	address xxx; // doesn't matter
	callFunctionWithParams(xxx, qToken, qTokenForCollateral, collateralTokenId, to, amount, f);
	// any change to the total supply of a qToken should be to a validQtoken
	assert totalSupplyBefore != qTokenA.totalSupply() => optionsFactory.isQToken(qToken);   
}


/* move to funds calculator
 rule amount_to_claim_LE_claimable(uint256 collateralTokenId,uint256 amount){
    env e;
	uint256 returnableCollateral;
    address collateralAsset;
    uint256 amountToClaim;
 
	address qtoken = collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId);
            returnableCollateral,
            collateralAsset,
            amountToClaim
         = calculateClaimableCollateral(e,collateralTokenId,amount);
	assert amountToClaim <= returnableCollateral; 
 }*/

// 1.  _claimCollateral(Actions.ClaimCollateralArgs memory _args)
//    the more the user claim the less his balance of collateral tokens
// 2. claim(x) + claim(y) == claim(x+y)
// 3. claim(x) <= balanceOf(x)

/* 	Rule: onlyAfterExpiry
 	Description: functions that should fail if called before exiry
	Formula: 
	Notes: 
*/
rule only_after_expiry(method f, bool eitherClaimOrExercise)	
{
	env e;
	address qToken; 
	uint256 amount;
	uint256 expiry = getExpiryTime(e,qToken);
		exercise(e, qToken, amount);

	assert e.block.timestamp > expiry;
}

/* 	Rule: additiveClaim
 	Description: Claim collateral of x and then of y should produce same result as claim collateral of (x+y)
	Formula:  claim(x) + claim(y) == claim(x+y)
	Notes: 
*/
rule additiveClaim(uint256 collateralTokenId, uint256 amount1, uint256 amount2){
	env e;
	uint256 balance1;
	uint256 balance2;
	storage init_state = lastStorage;
	claimCollateral(e, collateralTokenId, amount1);
	claimCollateral(e, collateralTokenId, amount2);
	balance1 = collateralToken.balanceOf(e.msg.sender, collateralTokenId); 
	claimCollateral(e, collateralTokenId, amount1 + amount2) at init_state;
	balance2 = collateralToken.balanceOf(e.msg.sender, collateralTokenId); 
	assert balance1 == balance2;
}

/* 	Rule: ratioAfterNeutralize
 	Description: increase in qTokens equals decrease in collateral tokens
	Formula: 
	Notes: 
*/
rule ratioAfterNeutralize(uint256 collateralTokenId, uint256 amount, address qToken){
	env e;
	require qToken == collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId);
	require qToken == qTokenA ; 
	require collateralToken.getCollateralTokenInfoTokenAsCollateral(collateralTokenId) != qTokenA;
	uint256 totalSupplyTBefore = qTokenA.totalSupply();
	uint256 totalSupplyCBefore = collateralToken.getTokenSupplies(collateralTokenId);
	neutralizePosition(e, collateralTokenId, amount);
	uint256 totalSupplyTAfter = qTokenA.totalSupply();
	uint256 totalSupplyCAfter = collateralToken.getTokenSupplies(collateralTokenId);
	assert  totalSupplyTAfter - totalSupplyTBefore == totalSupplyCAfter - totalSupplyCBefore;
	
}


/*  Rule: Mint Options QToken Correctness
		formula: mintOptionsPosition(to,qToken,amount) =>
				qToken.balanceOf(to) == qToken.balanceOf(to) + amount &&
				qToken.totalSupply() == qToken.totalSupply() + amount &&
				collateralToken.balanceOf(to,tokenId) == collateralToken.balanceOf(to,tokenId) + amount &&
				collateralToken.tokenSupplies(tokenId) == collateralToken.tokenSupplies(tokenId) + amount;
*/

/* 	Rule: mintOptionsCorrectness
 	Description: total supply option tokens increased by amount
	 			 total supply collateral tokens increased by amount
				 user's balance option tokens increased by amount
				 user's balance collateral tokens increased by amount
	Formula: 
	Notes: 
*/
rule mintOptionsCorrectness(uint256 collateralTokenId, uint amount){
	env e;
	address qToken = qTokenA;
	require qToken == collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId);
	require quantCalculator.qTokenToCollateralType(qToken) != qToken;
	require ghost_collateral(qToken,0) == collateralTokenId;
	require qTokenA.isCall(e);
	uint balanceOfqTokenBefore = qTokenA.balanceOf(e.msg.sender);
	uint totalSupplyqTokenBefore = qTokenA.totalSupply();
	uint balanceOfcolTokenBefore = collateralToken.balanceOf(e.msg.sender, collateralTokenId); 
	uint totalSupplyColTokenBefore = collateralToken.getTokenSupplies(collateralTokenId);
	require balanceOfqTokenBefore <= totalSupplyqTokenBefore &&
			balanceOfcolTokenBefore <= totalSupplyColTokenBefore;
		mintOptionsPosition(e,e.msg.sender,qTokenA,amount);
	uint balanceOfqTokenAfter = qTokenA.balanceOf(e.msg.sender);
	uint totalSupplyqTokenAfter = qTokenA.totalSupply();
	uint balanceOfcolTokenAfter = collateralToken.balanceOf(e.msg.sender, collateralTokenId);
	uint totalSupplyColTokenAfter = collateralToken.getTokenSupplies(collateralTokenId);
	require balanceOfqTokenAfter <= totalSupplyqTokenAfter &&
			balanceOfcolTokenAfter <= totalSupplyColTokenAfter;
	require amount < 1000 &&
			balanceOfqTokenBefore < 1000 &&
			totalSupplyqTokenBefore < 1000 &&
			balanceOfcolTokenBefore < 1000 &&
			totalSupplyColTokenBefore < 1000 &&
			balanceOfqTokenAfter < 1000 &&
			totalSupplyqTokenAfter < 1000 &&
			balanceOfcolTokenAfter < 1000 &&
			totalSupplyColTokenAfter < 1000;
	assert (balanceOfqTokenAfter == balanceOfqTokenBefore + amount &&
		   totalSupplyqTokenAfter == totalSupplyqTokenBefore + amount &&
		   balanceOfcolTokenAfter == balanceOfcolTokenBefore + amount &&
		   totalSupplyColTokenAfter == totalSupplyColTokenBefore + amount);
}

/* 	Rule: Mint options collateral correctness
		uint amount1;
		uint amount2;
		require amount1 > amount2;
		uint balance1;
		uint balance2;
		storage init_state = lastStorage;
		mintOptionsPosition(to,qToken,amount1);
		balance1 = collateral.balanceOf(controller);
		mintOptionsPosition(to,qToken,amount2) at init_state;
		balance2 = collateral.balanceOf(controller);
		assert balance1 - balance2 >= amount1 - amount2;
*/

/* Rule :Mint options collateral correctness
		collateral increase by the amount collateral of user decrease
		uint balanceControlerBefore = collateral.balanceOf(controler);
		uint balanceUserBefore = collateral.balanceOf(user);
		mintOptionsPosition(to,qToken,amount);
		balanceControlerAfter = collateral.balanceOf(controler);
		balanceUserAfter = collateral.balanceOf(user);
		assert balanceControlerAfter - balanceControlerBefore ==
			balanceUserBefore - balanceUserAfter;

*/
/* 	Rule: MintOptionsColCorrectness (Rule #7)
 	Description: increase in user's balance equals decrease in the contract's balance in the repective token
	Formula: 
	Notes: 
*/
rule MintOptionsColCorrectness(uint collateralTokenId, uint amount){
	env e;
	address qToken = collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId);
	require qToken == qTokenA;
	address asset = qTokenA.isCall(e) ? qTokenA.underlyingAsset(e) : qTokenA.strikeAsset(e);
	require asset != qToken;

	require ghost_collateral(qToken,0) == collateralTokenId;
	require quantCalculator.collateralRequirement(qTokenA,0,amount) == amount;

	require e.msg.sender != currentContract;//check if allowed
	
	uint    balanceControlerBefore = getTokenBalanceOf(e, asset, currentContract);
	uint    balanceUserBefore = getTokenBalanceOf(e, asset, e.msg.sender); 
	mintOptionsPosition(e, e.msg.sender, qTokenA, amount);
	uint    balanceControlerAfter = getTokenBalanceOf(e, asset, currentContract);
	uint    balanceUserAfter = getTokenBalanceOf(e, asset, e.msg.sender);
	assert (balanceControlerAfter - balanceControlerBefore ==
			balanceUserBefore - balanceUserAfter);
}

/* 	Rule: mintingOptionsInSteps (Rule #8)
 	Description: Minting options in steps requires the same or more collateral than minting all in one go
	Formula: 
	Notes: 
*/
rule mintingOptionsInSteps(uint256 collateralTokenId, uint256 amount1, uint256 amount2){
	env e;
	//setup qToken, collateralTokenID and underlying asset 
	address qToken = collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId);
	require qToken == qTokenA;
	require ghost_collateral(qToken,0) == collateralTokenId;	

	require e.msg.sender != currentContract;//check if allowed

	storage init_state = lastStorage;
	require quantCalculator.collateralRequirement(qTokenA,0,amount1) == amount1;
	mintOptionsPosition(e,e.msg.sender,qTokenA,amount1);
	require quantCalculator.collateralRequirement(qTokenA,0,amount2) == amount2;
	mintOptionsPosition(e,e.msg.sender,qTokenA,amount2);
	uint256	balance1 = collateralToken.balanceOf(e.msg.sender, collateralTokenId); 
	require quantCalculator.collateralRequirement(qTokenA,0,amount1 + amount2) == amount1 + amount2;
	mintOptionsPosition(e,e.msg.sender,qTokenA,amount1 + amount2) at init_state;
	uint256	balance2 = collateralToken.balanceOf(e.msg.sender, collateralTokenId); 
	assert balance1 >= balance2;

}
/* 	Rule: exercisingOptionsInSteps (Rule #9)
 	Description: Exercising options in steps doesn't yield higher payout than exercising in one go
	Formula: 
	Notes: 
*/
rule exercisingOptionsInSteps(uint256 collateralTokenId, uint256 amount1, uint256 amount2){
	env e;
	//setup qToken, collateralTokenID and underlying asset 
	address qToken = collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId);
	require qToken == qTokenA;
	require ghost_collateral(qToken,0) == collateralTokenId;	

	address asset = qTokenA.isCall(e) ? qTokenA.underlyingAsset(e) : qTokenA.strikeAsset(e);
	require asset != qToken;

	require e.msg.sender != currentContract;//check if allowed

	storage init_state = lastStorage;
	require quantCalculator.collateralRequirement(qTokenA,0,amount1) == amount1;
	exercise(e,qTokenA, amount1);
	require quantCalculator.collateralRequirement(qTokenA,0,amount2) == amount2;
	exercise(e,qTokenA, amount2);
	uint256	balance1 = getTokenBalanceOf(e, asset, e.msg.sender); 
	require quantCalculator.collateralRequirement(qTokenA,0,amount1 + amount2) == amount1 + amount2;
	exercise(e,qTokenA, amount1 + amount2) at init_state;
	uint256	balance2 = getTokenBalanceOf(e, asset, e.msg.sender);
	assert balance1 >= balance2;

}

/*
rule colToken_Impl_ColDeposited(uint256 collateralTokenId, address user){
uint colAmount = balanceOfCol(e,collateralTokenId,user);
}*/

rule solvencyUser(uint collateralTokenId, uint pricePerQToken, method f, uint valueOfCollateralTokenIdBefore, uint valueOfQTokenBefore, uint valueOfCollateralTokenIdAfter, uint valueOfQTokenAfter)
	{
	
	env e;
	address qToken = qTokenA;
	address qTokenForCollateral = 0;
	address to;
	uint256 amount;
	
	
	//setup qToken, collateralTokenID and underlying asset 
	setupQtokenCollateralTokenId(qToken, qTokenForCollateral, collateralTokenId);
	
	address asset = quantCalculator.qTokenToCollateralType(qToken);
	require asset != qToken;

	require ghost_claimableCollateral(collateralTokenId, amount) + ghost_exercisePayout(qToken, amount) <= max_uint;
	
	// need this because of issue in ghost 
	require ghost_collateralRequirement(qToken, qTokenForCollateral, amount) == quantCalculator.collateralRequirement(qToken, qTokenForCollateral, amount);


	//assume property proven in QuantCalculator
	require ghost_collateralRequirement(qToken, qTokenForCollateral, amount) == 
		ghost_claimableCollateral(collateralTokenId, amount) + ghost_exercisePayout(qToken, amount);

	require e.msg.sender != currentContract;//check if allowed
	require to == e.msg.sender;
	
	uint assetBalanceBefore = getTokenBalanceOf(e, asset, e.msg.sender);
	uint balanceColBefore = collateralToken.balanceOf(e.msg.sender, collateralTokenId); 
	require valueOfCollateralTokenIdBefore == ghost_claimableCollateral(collateralTokenId, balanceColBefore);
	uint balanceQTokenBefore = qTokenA.balanceOf(e.msg.sender);
	require valueOfQTokenBefore == ghost_exercisePayout(qToken,balanceQTokenBefore);

	
	mathint userAssetsBefore = assetBalanceBefore + valueOfCollateralTokenIdBefore + valueOfQTokenBefore;

	//callFunctionWithParams(e.msg.sender, qToken, qTokenForCollateral, collateralTokenId, to, amount, f);
	mintOptionsPosition(e,e.msg.sender,qTokenA,amount);
	
	uint assetBalanceAfter = getTokenBalanceOf(e, asset, e.msg.sender);
	uint balanceColAfter = collateralToken.balanceOf(e.msg.sender, collateralTokenId); 
	require valueOfCollateralTokenIdAfter == ghost_claimableCollateral(collateralTokenId, balanceColAfter);
	require valueOfCollateralTokenIdAfter == quantCalculator.claimableCollateral(collateralTokenId, balanceColAfter);
	uint balanceQTokenAfter = qTokenA.balanceOf(e.msg.sender);
	require valueOfQTokenAfter == ghost_exercisePayout(qToken,balanceQTokenAfter);
	require valueOfQTokenAfter == quantCalculator.exercisePayout(qToken,balanceQTokenAfter);
	mathint userAssetsAfter = assetBalanceAfter + valueOfCollateralTokenIdAfter + valueOfQTokenAfter;

	// assume additivity of exercisePayout and claimableCollateral
	additivityClaimableCollateral(collateralTokenId, balanceColAfter, balanceColBefore, amount);
	additivityExercisePayout(qToken, balanceQTokenAfter, balanceQTokenBefore, amount);

	assert (userAssetsBefore == userAssetsAfter);
}

/* 	Rule: balancesAfterExercise
 	Description: increase in user's balance equals decrease in the contract's balance in the repective token
	Formula: 
	Notes: 
*/
rule balancesAfterExercise(address qToken, uint256 amount){
	env e;
	require qTokenA == qToken;
	address asset = qTokenA.isCall(e) ? qTokenA.underlyingAsset(e) : qTokenA.strikeAsset(e);
	require asset != qToken;
	uint balanceUserBefore = getTokenBalanceOf(e, asset, e.msg.sender);
	uint balanceContractBefore = getTokenBalanceOf(e, asset, currentContract);
	exercise(e,qToken, amount);
	uint balanceUserAfter = getTokenBalanceOf(e, asset, e.msg.sender);
	uint balanceContractAfter = getTokenBalanceOf(e, asset, currentContract);
	assert balanceUserAfter - balanceUserBefore ==
		   balanceContractBefore - balanceContractAfter;
}

/* 	Rule: zeroCollateralZeroClaim
 	Description: claiming collateral having Zero collateral should result in Zero claimed
	Formula: 
	Notes: 
*/
rule zeroCollateralZeroClaim(uint256 collateralTokenId, uint256 amount){
	env e;
	address qToken = collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId);
	require qToken == qTokenA;
	address asset = qTokenA.isCall(e) ? qTokenA.underlyingAsset(e) : qTokenA.strikeAsset(e);
	uint balanceContractBefore = getTokenBalanceOf(e, asset, currentContract);
	uint balanceUserColBefore = collateralToken.balanceOf(e.msg.sender, collateralTokenId); 
	//require collateralTokenId == address(0);
	claimCollateral(e,collateralTokenId, amount);
	uint balanceContractAfter = getTokenBalanceOf(e, asset, currentContract);
	assert balanceUserColBefore == 0 => balanceContractBefore == balanceContractAfter;
}
/* 	Rule: claimCorrectness
 	Description:
	Formula: 
	Notes: 
*/
rule claimCorrectness(uint256 collateralTokenId, uint256 amount){ // to complete!
	env e;
	address qToken = collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId);
	require qToken == qTokenA;
	address asset = qTokenA.isCall(e) ? qTokenA.underlyingAsset(e) : qTokenA.strikeAsset(e);
	uint balanceContractBefore = getTokenBalanceOf(e, asset, currentContract);
	uint balanceUserColBefore = collateralToken.balanceOf(e.msg.sender, collateralTokenId); 
	//require collateralTokenId == address(0);
	claimCollateral(e,collateralTokenId, amount);
	uint balanceContractAfter = getTokenBalanceOf(e, asset, currentContract);
	assert balanceUserColBefore == 0 => balanceContractBefore == balanceContractAfter;
}


/*
rule After_mintSpread(address qToken,address qTokenForCollateral,uint256 amount){
	env e;
	mintSpread(qToken, qTokenForCollateral, amount);
}
*/
/* 
	Rule: Inverse

	minting (simple or spread) and then neutralize are inverse


	minting and then claimCollateral and exercise are inverse  (also for spread?)

*/

// getExercisePayout, getCollateralRequirement, calculateClaimableCollateral
// return the same ERC20token for the same qtoken/collateralTokenID
rule getSameToken(uint256 collateralTokenId, uint256 amount, address optionsFactory) {
    env e;
    uint256 returnableCollateral;
    address collateralAsset;
    uint256 amountToClaim;

	//setup qToken, collateralTokenID and asset
	address qToken = collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId);
	require qToken == qTokenA;
	require collateralToken.getCollateralTokenInfoTokenAsCollateral(collateralTokenId) == 0;
	require ghost_collateral(qToken,0) == collateralTokenId;
	address asset = qTokenA.isCall(e) ? qTokenA.underlyingAsset(e) : qTokenA.strikeAsset(e);

    // token from calculateClaimableCollateral
	returnableCollateral,
	collateralAsset,
	amountToClaim = quantCalculator.calculateClaimableCollateral(e, collateralTokenId, amount, optionsFactory, e.msg.sender);

	// token from getExercisePayout
	bool isSettled;
    address payoutToken;
    uint256 payoutAmount;

    isSettled,
    payoutToken,
    payoutAmount = quantCalculator.getExercisePayout(e, qToken, optionsFactory, amount);

    assert collateralAsset == payoutToken;

    // get asset from getCollateralRequirement and check for equality.
}

////////////////////////////////////////////////////////////////////////////
//                       Helper Functions                                 //
////////////////////////////////////////////////////////////////////////////
    

// easy to use dispatcher

function callFunctionWithParams(address expectedSender, address qToken, address qTokenForCollateral, uint256 collateralTokenId, address to, uint256 amount, method f) {
	env e;
	require e.msg.sender == expectedSender;

	if (f.selector == exercise(address,uint256).selector) {
		exercise(e, qToken, amount);
	}
	else if (f.selector == mintOptionsPosition(address,address,uint256).selector) {
		require qTokenForCollateral == 0;
		mintOptionsPosition(e, to, qToken, amount); 
	} 
	else if (f.selector == mintSpread(address,address,uint256).selector) {
		mintSpread(e, qToken, qTokenForCollateral, amount);
	}
	else if (f.selector == claimCollateral(uint256,uint256).selector ) {
		claimCollateral(e, collateralTokenId, amount);
	}
	else if (f.selector == neutralizePosition(uint256,uint256).selector) {
		neutralizePosition(e, collateralTokenId, amount);
	}
	else{
		calldataarg args;
		f(e,args);
	}
}


// setup the connections between qTokens and collateralTokenID
function setupQtokenCollateralTokenId(address qToken, address qTokenForCollateral, uint collateralTokenId) {
	require qToken == collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId);
	require ghost_collateral(qToken,qTokenForCollateral) == collateralTokenId;
}

// assume additivity of ClaimableCollateral
function additivityClaimableCollateral(uint collateralTokenId, uint sum, uint x, uint y ) {
	require x + y <= max_uint;
	require sum == x + y;
	
	require ghost_claimableCollateral(collateralTokenId, x) == quantCalculator.claimableCollateral(collateralTokenId, x);
	require ghost_claimableCollateral(collateralTokenId, y) == quantCalculator.claimableCollateral(collateralTokenId, y);
	require ghost_claimableCollateral(collateralTokenId, sum) == quantCalculator.claimableCollateral(collateralTokenId, sum);

	require ghost_claimableCollateral(collateralTokenId, x) + ghost_claimableCollateral(collateralTokenId, y) <= max_uint;
	require ghost_claimableCollateral(collateralTokenId, sum) == ghost_claimableCollateral(collateralTokenId, x) + ghost_claimableCollateral(collateralTokenId, y);
}

function additivityExercisePayout(address qToken, uint sum, uint x, uint y ) {
	require x + y <= max_uint;
	require sum == x + y;

	require ghost_exercisePayout(qToken, sum) == quantCalculator.exercisePayout(qToken, sum);
	require ghost_exercisePayout(qToken, x) == quantCalculator.exercisePayout(qToken, x);
	require ghost_exercisePayout(qToken, y) == quantCalculator.exercisePayout(qToken, y);

	require ghost_exercisePayout(qToken, x) + ghost_exercisePayout(qToken, y) <= max_uint;
	require ghost_exercisePayout(qToken, sum) == ghost_exercisePayout(qToken, x) + ghost_exercisePayout(qToken, y);
}


function additivityCollateralRequirement(address qToken, address qTokenForCollateral, uint sum, uint x, uint y ) {
	require x + y <= max_uint;
	require sum == x + y;

	require ghost_collateralRequirement(qToken, qTokenForCollateral, sum) == quantCalculator.collateralRequirement(qToken, qTokenForCollateral, sum);
	require ghost_collateralRequirement(qToken, qTokenForCollateral, x) == quantCalculator.collateralRequirement(qToken, qTokenForCollateral, x);
	require ghost_collateralRequirement(qToken, qTokenForCollateral, y) == quantCalculator.collateralRequirement(qToken, qTokenForCollateral, y);

	require ghost_collateralRequirement(qToken, qTokenForCollateral, x) + ghost_collateralRequirement(qToken, qTokenForCollateral, y) <= max_uint;
	require ghost_collateralRequirement(qToken, qTokenForCollateral, sum) == ghost_collateralRequirement(qToken, qTokenForCollateral, x) + ghost_collateralRequirement(qToken, qTokenForCollateral, y);
}
