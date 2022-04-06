/*
    This is a specification file for smart contract verification with the Certora prover.
    For more information, visit: https://www.certora.com/

    This file is run with spec/scripts/runController.sh
	Assumptions: QunatCalculator property:
	collateralRequirement(qToken, qTokenForCollateral, amount) == 
			claimableCollateral(collateralTokenId, amount) + exercisePayout(qToken, amount);
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
	    

	
	// QToken methods to be called with one of the tokens (DummyERC20*, DummyWeth)	
	mint(address account, uint256 amount) => DISPATCHER(true)
	burn(address account, uint256 amount) => DISPATCHER(true)
    underlyingAsset() returns (address) => DISPATCHER(true)
	qTokenA.underlyingAsset() returns (address) envfree
	strikeAsset() returns (address) => DISPATCHER(true)
	qTokenA.strikeAsset() returns (address) envfree
	strikePrice() returns (uint256) => DISPATCHER(true)
	expiryTime() returns (uint256) => DISPATCHER(true)	
	isCall() returns (bool) => DISPATCHER(true)
	qTokenA.isCall() returns (bool) envfree

	// IERC20 methods to be called with one of the tokens (DummyERC20A, DummyERC20A) or QToken
	qTokenA.balanceOf(address) returns (uint256) envfree
	balanceOf(address) returns (uint256) => DISPATCHER(true) 
	totalSupply() returns (uint256) => DISPATCHER(true)
	qTokenA.totalSupply() returns (uint256) envfree
	qTokenB.balanceOf(address) returns (uint256) envfree
	qTokenB.totalSupply() returns (uint256) envfree
	transferFrom(address from, address to, uint256 amount) => DISPATCHER(true)
	transfer(address to, uint256 amount) => DISPATCHER(true)


	// OptionsFactory
	optionsFactory.isQToken(address _qToken) returns (bool) envfree 
	isQToken(address _qToken) returns (bool) => DISPATCHER(true)
	collateralToken() => NONDET
	quantConfig() => NONDET
	
	// CollateralToken
	mintCollateralToken(address,uint256,uint256) => DISPATCHER(true)
	burnCollateralToken(address,uint256,uint256) => DISPATCHER(true)
	idToInfo(uint256) => DISPATCHER(true)
	collateralToken.idToInfo(uint256) returns (address,address) envfree
	collateralToken.getCollateralTokenId(address p,address q) returns (uint256) envfree 
	getCollateralTokenId(address p,address q) returns (uint256) => ghost_collateral(p,q)
	collateralToken.getTokenSupplies(uint) returns (uint) envfree
	collateralToken.getCollateralTokenInfoTokenAddress(uint) returns (address) envfree
	collateralToken.getCollateralTokenInfoTokenAsCollateral(uint)returns (address) envfree
	collateralToken.balanceOf(address, uint256) returns (uint256) envfree
	balanceOf(address, uint256) returns (uint256) => DISPATCHER(true)
	createCollateralToken(address,address) => NONDET
	
	
	// Computations
	
	quantCalculator.qTokenToCollateralType(address) returns (address) envfree
	
	quantCalculator.claimableCollateral(uint256 collateralTokenId,
        uint256 amount
	) returns (uint256) envfree

	quantCalculator.getClaimableCollateralValue(uint256 collateralTokenId,
        uint256 amount
	) returns (uint256) envfree
	getClaimableCollateralValue(uint256 collateralTokenId,
        uint256 amount
	) returns (uint256) => ghost_claimableCollateral(collateralTokenId,amount) 

	quantCalculator.getCollateralRequirementValue(
        address qTokenToMint,
        address qTokenForCollateral,
        uint256 amount
    ) returns (uint256) envfree 
	getCollateralRequirementValue(
        address qTokenToMint,
        address qTokenForCollateral,
        uint256 amount
    ) returns (uint256) => ghost_collateralRequirement(qTokenToMint,qTokenForCollateral,amount) 

	quantCalculator.collateralRequirement(
        address qTokenToMint,
        address qTokenForCollateral,
        uint256 amount
    ) returns (uint256) envfree 


	quantCalculator.getExercisePayoutValue(
		address qToken,
		uint amount
	) returns (uint256) envfree 
	getExercisePayoutValue(
		address qToken,
		uint amount
	) returns (uint256) => ghost_exercisePayout(qToken,amount) 

	quantCalculator.exercisePayout(
		address qToken,
		uint amount
	) returns (uint256) envfree
	exercisePayout(
		address qToken,
		uint amount
	) returns (uint256) => ghost_exercisePayout(qToken,amount)

	quantCalculator.getNeutralizationPayoutValue(address qTokenToMint,
												 address qTokenForCollateral,
												 uint256 amount
	) returns (uint256) envfree
	getNeutralizationPayoutValue(address qTokenToMint,
												 address qTokenForCollateral,
												 uint256 amount
	) returns (uint256) => ghost_neutralizationPayout(qTokenToMint, qTokenForCollateral, amount)

	//ERC1155Receiver
	onERC1155Received(address,address,uint256,uint256,bytes) => NONDET

}





////////////////////////////////////////////////////////////////////////////
//                       Ghost                                            //
////////////////////////////////////////////////////////////////////////////


// Ghosts are like additional function
// A ghost to represent the uniqueness of collateralTokenId for each pair of qTokens
ghost ghost_collateral(address , address) returns uint;

// A ghost to represent the amount of neutralizationPayout per each pair of qTokens and amount
ghost ghost_neutralizationPayout(address , address , uint) returns uint;

// A ghost to represent the amount of claimableCollateral per collateralId and amount
ghost ghost_claimableCollateral(uint256, uint256) returns uint{
	axiom forall uint256 cId. ghost_claimableCollateral(cId,0) == 0;
}

// A ghost to represent the amount of collateralRequirement per each pair of qTokens and amount
// The axiom assumes monotonicity 
ghost ghost_collateralRequirement(address, address, uint256) returns uint {
	axiom forall address p. forall address q. forall uint256 amount1. forall uint256 amount2.
	amount1 > amount2 => ghost_collateralRequirement(p,q,amount1) >= ghost_collateralRequirement(p,q,amount2);
	}

// A ghost to represent the amount of exercisePayout per qToken and amount
// The axiom assumes monotonicity 
ghost ghost_exercisePayout(address, uint256) returns uint {
	axiom forall address p. forall uint256 amount1. forall uint256 amount2.
	amount1 > amount2 => ghost_exercisePayout(p,amount1) >= ghost_exercisePayout(p,amount2);
}

////////////////////////////////////////////////////////////////////////////
//                       Invariants                                       //
////////////////////////////////////////////////////////////////////////////



/* 	Rule: balanceVSsupply
 	Description:  totalSupply always greater than blance of user
	Formula: 	  qTokenA.totalSupply() >= qTokenA.balanceOf(e.msg.sender)
	Notes: 
*/
invariant balanceVSsupply(uint collateralTokenId, address qToken, env e)
		qToken == collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId) &&
		qToken == qTokenA &&
		qToken != quantCalculator.qTokenToCollateralType(qToken) &&
		qToken != collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId)
		=> qTokenA.totalSupply() >= qTokenA.balanceOf(e.msg.sender)



////////////////////////////////////////////////////////////////////////////
//                       General Rules                                   //
////////////////////////////////////////////////////////////////////////////

/* 	Rule: Valid QToken  
 	Description:  Only valid QToken can be used in functions that change the QToken's totalSupply 
	Formula: 	{ t = qToken.totalSupply() }
					op
				{ qToken.totalSupply() != t => qToken.isValid() }
	Notes: 
*/
rule validQtoken(method f)  
		filtered { f -> f.selector != certorafallback_0().selector &&
						f.selector != executeMetaTransaction((uint256,uint256,address,(uint8,address,address,address,uint256,uint256,bytes)[]),uint256,bytes32,bytes32,uint8).selector  && 
						f.selector != initialize(string,string,address,address).selector }			
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

/* 	Rule: solvencyUser  
 	Description: The user can not gain excess assets or lose assets. USer's total asset is computed as the balanceOf in the asset, the value of his qTokens and the value of his collateralTokens
	Formula: 	{ before = asset.balanceOf(u) +  exercisePayout(qTokenA.balanceOf(u)) + claimableCollateral(collateralTokenId, collateralToken.balanceOf(u, collateralTokenId)) }
                    op
                { asset.balanceOf(u) +  exercisePayout(qTokenA.balanceOf(u)) + claimableCollateral(collateralTokenId, collateralToken.balanceOf(u, collateralTokenId)) = before }
	Notes: 
*/
rule solvencyUser(uint collateralTokenId, uint pricePerQToken, method f, uint valueOfCollateralTokenIdBefore, uint valueOfQTokenBefore, uint valueOfCollateralTokenIdAfter, uint valueOfQTokenAfter)
		filtered { f -> f.selector != certorafallback_0().selector &&
						f.selector != executeMetaTransaction((uint256,uint256,address,(uint8,address,address,address,uint256,uint256,bytes)[]),uint256,bytes32,bytes32,uint8).selector  && 
						f.selector != mintSpread(address, address, uint).selector &&
						f.selector != initialize(string,string,address,address).selector }	

	{
	
	env e;
	address qToken;
	address qTokenForCollateral;
	address to;
	uint256 amount;
	
	require amount != 0;
	
	//setup qToken, collateralTokenID and underlying asset 
	setupQtokenCollateralTokenId(qToken, qTokenForCollateral, collateralTokenId);

	require qToken == qTokenA;
	require qTokenForCollateral == 0 ;
	
	address asset = quantCalculator.qTokenToCollateralType(qToken);
	require asset != qToken;

	require ghost_claimableCollateral(collateralTokenId, amount) + ghost_exercisePayout(qToken, amount) <= max_uint;
	
	// need this because of issue in ghost 
	require ghost_collateralRequirement(qToken, qTokenForCollateral, amount) == quantCalculator.collateralRequirement(qToken, qTokenForCollateral, amount);


	//assume main property of QuantCalculator
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

	callFunctionWithParams(e.msg.sender, qToken, qTokenForCollateral, collateralTokenId, to, amount, f);	
	
	uint assetBalanceAfter = getTokenBalanceOf(e, asset, e.msg.sender);
	uint balanceColAfter = collateralToken.balanceOf(e.msg.sender, collateralTokenId); 
	require valueOfCollateralTokenIdAfter == ghost_claimableCollateral(collateralTokenId, balanceColAfter);
	require valueOfCollateralTokenIdAfter == quantCalculator.claimableCollateral(collateralTokenId, balanceColAfter);
	uint balanceQTokenAfter = qTokenA.balanceOf(e.msg.sender);
	require valueOfQTokenAfter == ghost_exercisePayout(qToken,balanceQTokenAfter);
	require valueOfQTokenAfter == quantCalculator.exercisePayout(qToken,balanceQTokenAfter);
	
	mathint userAssetsAfter = assetBalanceAfter + valueOfCollateralTokenIdAfter + valueOfQTokenAfter ;

	// assume additivity of exercisePayout and claimableCollateral
	additivityClaimableCollateral(collateralTokenId, balanceColAfter, balanceColBefore, amount);
	additivityExercisePayout(qToken, amount, balanceQTokenBefore, balanceQTokenAfter);

	assert (userAssetsBefore == userAssetsAfter );
}

/* 	Rule: integrityOfTotals 
 	Description: User owns all the qTokens IFF user owns all the collateral tokens
	Formula: { qToken.balanceOf(u) == qToken.totalSupply()  <=>  Collateral.balanceOf(u) == Collateral.totalSupply() }
															op
			 { qToken.balanceOf(u) == qToken.totalSupply()  <=>  Collateral.balanceOf(u) == Collateral.totalSupply() }
	Notes: 
*/
rule integrityOfTotals(uint256 collateralTokenId, uint256 amount, method f){
	env e;
	address qToken = qTokenA;
	address asset = qTokenA.isCall() ? qTokenA.underlyingAsset() : qTokenA.strikeAsset();
	require asset != qToken;
	address qTokenForCollateral;
	address to;
	require e.msg.sender != currentContract;
	require to == e.msg.sender;

	//setup qToken, collateralTokenID and underlying asset 
	setupQtokenCollateralTokenId(qToken, qTokenForCollateral, collateralTokenId);

	uint userBalanceOfQToken = qTokenA.balanceOf(e.msg.sender);
	uint userBalanceOfCol = collateralToken.balanceOf(e.msg.sender, collateralTokenId);
	uint qTokenTotalSupply = qTokenA.totalSupply();
	uint ColTotalSupply = collateralToken.getTokenSupplies(collateralTokenId);
	require userBalanceOfQToken == qTokenTotalSupply <=> userBalanceOfCol == ColTotalSupply;
	callFunctionWithParams(e.msg.sender, qTokenA, qTokenForCollateral, collateralTokenId, to, amount, f);

	assert userBalanceOfQToken == qTokenTotalSupply <=> userBalanceOfCol == ColTotalSupply;
}

/* 	Rule: getSameToken 
 	Description: getExercisePayout, getCollateralRequirement, calculateClaimableCollateral
				 return the same ERC20token for the same qtoken/collateralTokenID
	Formula:  (_, payoutToken, _ ) = getExercisePayout && (_, calculateClaimableCollateral, _ calculateClaimableCollateral(collateralTokenId,x,u) => payoutToken == calculateClaimableCollateral
	Notes: 
*/
rule getSameToken(uint256 collateralTokenId, uint256 amount, address optionsFactory) {
    env e;
    address collateralAsset;
	address qToken;

	//setup qToken, collateralTokenID and asset
	setupQtokenCollateralTokenId(qToken, 0, collateralTokenId);
	require collateralToken.getCollateralTokenInfoTokenAsCollateral(collateralTokenId) != qTokenA;
	require qToken == qTokenA;
	address asset = qTokenA.isCall() ? qTokenA.underlyingAsset() : qTokenA.strikeAsset();

    // token from calculateClaimableCollateral
	_,
	collateralAsset,
	_ = quantCalculator.calculateClaimableCollateral(e, collateralTokenId, amount, e.msg.sender);

	// token from getExercisePayout
	bool isSettled;
    address payoutToken;

    isSettled,
    payoutToken,
    _ = quantCalculator.getExercisePayout(e, qToken, amount);

    assert collateralAsset == payoutToken;

    
}

////////////////////////////////////////////////////////////////////////////
//                       Neutralize Options Rules                         //
////////////////////////////////////////////////////////////////////////////

/* 	Rule: ratioAfterNeutralize
 	Description: increase in qTokens equals decrease in collateral tokens
	Formula: { mintBefore = mint.totalSupply() &&
			   CollBefore = collateralToken.getTokenSupplies(cId)}
			   neutralizePosition(cId, amount)
			 { mint.totalSupply() - mintBefore == collateralToken.getTokenSupplies(cId) - CollBefore }
	Notes: 
*/
rule ratioAfterNeutralize(uint256 collateralTokenId, uint256 amount, address qToken){
	env e;
	//setup qToken, collateralTokenID and asset
	setupQtokenCollateralTokenId(qToken, 0, collateralTokenId);
	require qToken == qTokenA ; 
	require collateralToken.getCollateralTokenInfoTokenAsCollateral(collateralTokenId) != qTokenA;
	uint256 totalSupplyTBefore = qTokenA.totalSupply();
	uint256 totalSupplyCBefore = collateralToken.getTokenSupplies(collateralTokenId);
	neutralizePosition(e, collateralTokenId, amount);
	uint256 totalSupplyTAfter = qTokenA.totalSupply();
	uint256 totalSupplyCAfter = collateralToken.getTokenSupplies(collateralTokenId);
	assert  totalSupplyTAfter - totalSupplyTBefore == totalSupplyCAfter - totalSupplyCBefore;
	
}

/* 	Rule: neutralizeBurnCorrectness (Rule #19)
 	Description:  Neutralizing options must always burn the amount passed into the function
	Formula: { mintBefore = qTokenA.totalSupply() &&
			   forCollBefore = qTokenB.totalSupply() && amount > 0 }
			   neutralizePosition(cId, amount)
			 { qTokenA.totalSupply() = mintBefore - amount  XOR
			   qTokenB.totalSupply() = forCollBefore - amount }
	Notes: 
*/
rule neutralizeBurnCorrectness(uint collateralTokenId, uint amount){
	env e;
	address qTokenToMint;
	address qTokenForCollateral;

	require qTokenToMint == qTokenA;
	require qTokenForCollateral == qTokenB;

	require e.msg.sender != currentContract;

	//setup qToken, collateralTokenID and underlying asset 
	setupQtokenCollateralTokenId(qTokenToMint, qTokenForCollateral, collateralTokenId);

	require amount != 0;

	uint totalSupplyBeforeA = qTokenA.totalSupply();
	uint totalSupplyBeforeB = qTokenB.totalSupply();
		neutralizePosition(e, collateralTokenId, amount);
	uint totalSupplyAfterA = qTokenA.totalSupply();
	uint totalSupplyAfterB = qTokenB.totalSupply();
	
	assert (totalSupplyBeforeA - amount == totalSupplyAfterA) !=
		   (totalSupplyBeforeB - amount == totalSupplyAfterB);
}

////////////////////////////////////////////////////////////////////////////
//                       Minting Options Rules                            //
////////////////////////////////////////////////////////////////////////////


/*  Rule: Integrity of Mint Options 
		formula: 
		{b = qToken.balanceOf(to)  && t = qToken.totalSupply() &&
		bCid = collateralToken.balanceOf(to,tokenId) &&
		tCid = collateralToken.tokenSupplies(tokenId)
		 }
		mintOptionsPosition(to,qToken,amount) 
		{		qToken.balanceOf(to) ==  + amount &&
				qToken.totalSupply() ==  + amount &&
				collateralToken.balanceOf(to,tokenId) == bCid + amount &&
				collateralToken.tokenSupplies(tokenId) == tCid + amount }
*/
rule integrityMintOptions(uint256 collateralTokenId, uint amount){
	env e;
	address qToken = qTokenA;
	address qTokenForCollateral = 0;
	setupQtokenCollateralTokenId(qToken, qTokenForCollateral, collateralTokenId);
	require quantCalculator.qTokenToCollateralType(qToken) != qToken;
	
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
	assert (balanceOfqTokenAfter == balanceOfqTokenBefore + amount &&
		   totalSupplyqTokenAfter == totalSupplyqTokenBefore + amount &&
		   balanceOfcolTokenAfter == balanceOfcolTokenBefore + amount &&
		   totalSupplyColTokenAfter == totalSupplyColTokenBefore + amount);
}


/* 	Rule: MintOptionsColCorrectness (Rule #7)
 	Description: increase in user's balance equals decrease in the contract's balance in the respective token
	Formula: { beforeUser = asset.balanceOf(u)
			   beforeContract = asset.balanceOf(c) }
			   	mintOptionsPosition(u, qToken, amount)
			 { beforeUser - asset.balanceOf(u) = asset.balanceOf(c)  - beforeContract }
	Notes: 
*/
rule mintOptionsColCorrectness(uint collateralTokenId, uint amount){
	env e;
	address qToken = qTokenA;
	
	setupQtokenCollateralTokenId(qToken, 0, collateralTokenId);
	address asset = qTokenA.isCall() ? qTokenA.underlyingAsset() : qTokenA.strikeAsset();
	require asset != qToken;

	require quantCalculator.collateralRequirement(qTokenA,0,amount) == amount;

	require e.msg.sender != currentContract; //check if allowed
	
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
	Formula:  mintOptionsPosition(u, qToken, x);mintOptionsPosition(u, qToken, y) ~ mintOptionsPosition(u, qToken, x + y)
			with respect to  collateralToken.balanceOf(u, cId)
	Notes: This rules timesout 

rule mintingOptionsInSteps(uint256 collateralTokenId, uint256 amount1, uint256 amount2){
	env e;
	//setup qToken, collateralTokenID and underlying asset 
	address qToken = qTokenA;
	setupQtokenCollateralTokenId(qToken, 0, collateralTokenId);

	require e.msg.sender != currentContract;

	storage init_state = lastStorage;
	uint sum = amount1 + amount2;

	mintOptionsPosition(e,e.msg.sender,qTokenA,amount1);
	mintOptionsPosition(e,e.msg.sender,qTokenA,amount2);
	uint256	balance1 = collateralToken.balanceOf(e.msg.sender, collateralTokenId);

	additivityCollateralRequirement(qTokenA, 0, sum, amount1, amount2);
	mintOptionsPosition(e,e.msg.sender,qTokenA,sum) at init_state;

	uint256	balance2 = collateralToken.balanceOf(e.msg.sender, collateralTokenId); 

	assert balance1 == balance2;
}
*/
////////////////////////////////////////////////////////////////////////////
//                       Exercising Options Rules                         //
////////////////////////////////////////////////////////////////////////////

/* 	Rule: exercisingOptionsInSteps (Rule #9)
 	Description: Exercising options in steps doesn't yield higher payout than exercising in one go
	Formula:  exercise(qToken, x);exercise(qToken, y);
				~
			 exercise(qToken, x + y)
			
	Notes:  This rules timesout 
*/
/*
rule exercisingOptionsInSteps(uint256 collateralTokenId, uint256 amount1, uint256 amount2){
	env e;
	//setup qToken, collateralTokenID and underlying asset 
	address qToken = qTokenA;
	setupQtokenCollateralTokenId(qToken, 0, collateralTokenId);

	address asset = qTokenA.isCall() ? qTokenA.underlyingAsset() : qTokenA.strikeAsset();
	require asset != qToken;
	require e.msg.sender != currentContract;
	storage init_state = lastStorage;
	
	exercise(e,qToken, amount1);
	exercise(e,qToken, amount2);
	uint256	balance1 = getTokenBalanceOf(e, asset, e.msg.sender); 

	uint256 sum = amount1 + amount2;
	additivityExercisePayout(qToken, sum, amount1, amount2);

	exercise(e,qToken, sum) at init_state;
	uint256	balance2 = getTokenBalanceOf(e, asset, e.msg.sender);

	assert balance1 == balance2;
}
*/

/* 	Rule: exerciseBurnCorrectness (Rule #11)
 	Description:  Exercising options must always burn the amount passed into the function
	Formula: { before = qTokenA.totalSupply() }
					exercise(qToken, amount)
			 { qTokenA.totalSupply() = before - amount }
	Notes: 
*/
rule exerciseBurnCorrectness(uint collateralTokenId, uint amount){
	env e;
	//setup qToken, collateralTokenID and underlying asset 
	address qToken = qTokenA;
	setupQtokenCollateralTokenId(qToken, 0, collateralTokenId);
	address asset = qTokenA.isCall() ? qTokenA.underlyingAsset() : qTokenA.strikeAsset();
	require asset != qToken;
	require e.msg.sender != currentContract;//check if allowed

	uint totalSupplyBefore = qTokenA.totalSupply();
	require amount == qTokenA.balanceOf(e.msg.sender);

	exercise(e,qTokenA, 0);

	uint totalSupplyAfter = qTokenA.totalSupply();
	assert totalSupplyBefore - amount == totalSupplyAfter;
}

/* 	Rule: balancesAfterExercise
 	Description: increase in user's balance equals decrease in the contract's balance in the respective token
	Formula: { beforeUser = asset.balanceOf(u)
			   beforeContract = asset.balanceOf(system) }
			   	exercise(qToken, amount);
			 { asset.balanceOf(u) - beforeUser == beforeContract - asset.balanceOf(system) }
	Notes: 
*/
rule balancesAfterExercise(address qToken, uint256 amount){
	env e;
	require qTokenA == qToken;
	address asset = qTokenA.isCall() ? qTokenA.underlyingAsset() : qTokenA.strikeAsset();
	require asset != qToken;
	uint balanceUserBefore = getTokenBalanceOf(e, asset, e.msg.sender);
	uint balanceContractBefore = getTokenBalanceOf(e, asset, currentContract);
	exercise(e,qToken, amount);
	uint balanceUserAfter = getTokenBalanceOf(e, asset, e.msg.sender);
	uint balanceContractAfter = getTokenBalanceOf(e, asset, currentContract);
	assert balanceUserAfter - balanceUserBefore ==
		   balanceContractBefore - balanceContractAfter;
}

/* 	Rule: onlyAfterExpiry
 	Description: exercise  should fail if called before expiry
	Formula: { exercise(a,b)  did not revert }
				=> timestamp > expiry
	Notes: 
*/
rule onlyAfterExpiry()	
{
	env e;
	env t;
	address qToken;
	uint collateralTokenId;
	uint256 amount;
	uint256 expiry = getExpiryTime(e,qToken);
	
	setupQtokenCollateralTokenId(qToken, 0, collateralTokenId);
	exercise(e, qToken, amount);
	assert e.block.timestamp > expiry;
}

////////////////////////////////////////////////////////////////////////////
//                       Minting Spread Options Rules                      //
////////////////////////////////////////////////////////////////////////////

/* 	Rule: mintSpreadBalancesCorrectness (Rule #13)
 	Description: Minting spreads must burn the qTokens provided as collateral, mint the desired qTokens and also mint collateral tokens representing the spread
	Formula: 
	Notes: 
*/
rule mintSpreadBalancesCorrectness(address qTokenToMint, address qTokenForCollateral, uint amount){
	env e;
	uint collateralTokenId;
	//setup qToken, collateralTokenID and underlying asset 
	setupQtokenCollateralTokenId(qTokenToMint, qTokenForCollateral, collateralTokenId);
	require qTokenToMint == qTokenA;
	require qTokenForCollateral == qTokenB;

	require ghost_collateralRequirement(qTokenToMint, qTokenForCollateral, amount) == quantCalculator.collateralRequirement(qTokenToMint, qTokenForCollateral, amount);
	//assume property proven in QuantCalculator
	require ghost_collateralRequirement(qTokenToMint, qTokenForCollateral, amount) == 
		ghost_claimableCollateral(collateralTokenId, amount) + ghost_exercisePayout(qTokenToMint, amount);

	require e.msg.sender != currentContract;//check if allowed


	address asset = quantCalculator.qTokenToCollateralType(qTokenToMint);
	require asset != qTokenToMint && asset != qTokenForCollateral;
	uint	balanceAssetUserBefore = getTokenBalanceOf(e, asset, e.msg.sender);
	uint	balanceAssetContBefore = getTokenBalanceOf(e, asset, currentContract);

	uint qTokenForColBefore = qTokenB.balanceOf(e.msg.sender);
	require qTokenForColBefore >= amount;
	uint qTokenForColTotalBefore = qTokenB.totalSupply();
	uint balanceColBefore = collateralToken.balanceOf(e.msg.sender, collateralTokenId);
	uint balanceColTotalBefore = collateralToken.getTokenSupplies(collateralTokenId);
	uint qTokenToMintBefore = qTokenA.balanceOf(e.msg.sender);
	uint qTokenToMintTotalBefore = qTokenA.totalSupply();

	mintSpread(e, qTokenA, qTokenB, amount);

	uint balanceAssetUserAfter = getTokenBalanceOf(e, asset, e.msg.sender);
	uint balanceAssetContAfter = getTokenBalanceOf(e, asset, currentContract);
	uint qTokenForColAfter = qTokenB.balanceOf(e.msg.sender);
	uint qTokenForColTotalAfter = qTokenB.totalSupply();
	uint balanceColAfter = collateralToken.balanceOf(e.msg.sender, collateralTokenId);
	uint balanceColTotalAfter = collateralToken.getTokenSupplies(collateralTokenId);
	uint qTokenToMintAfter = qTokenA.balanceOf(e.msg.sender);
	uint qTokenToMintTotalAfter = qTokenA.totalSupply();

	assert balanceAssetUserBefore - balanceAssetUserAfter ==
		   balanceAssetContAfter - balanceAssetContBefore   &&
		   qTokenForColBefore == qTokenForColAfter + amount &&
		   qTokenForColTotalBefore == qTokenForColTotalAfter + amount &&
		   balanceColBefore == balanceColAfter - amount &&
		   balanceColTotalBefore == balanceColTotalAfter - amount &&
		   qTokenToMintBefore == qTokenToMintAfter - amount &&
		   qTokenToMintTotalBefore == qTokenToMintTotalAfter - amount;

}


////////////////////////////////////////////////////////////////////////////
//                       Claiming Collateral Rules                        //
////////////////////////////////////////////////////////////////////////////

/* 	Rule: additiveClaim (rule #15)
 	Description: Claim collateral of x and then of y should produce same result as claim collateral of (x+y)
	Formula:  claimCollateral(cId, x); claimCollateral(cId, y) ~ claimCollateral(cID, x+y)
			with respect to collateralToken.balanceOf(e.msg.sender, cId)
	Notes: 
*/
rule additiveClaim(address qToken, address qTokenForCollateral, 
				uint256 collateralTokenId, uint256 amount1, uint256 amount2){
	env e;
	
	setupQtokenCollateralTokenId(qToken, qTokenForCollateral, collateralTokenId);
	storage init_state = lastStorage;
	require amount1 != 0 && amount2 != 0; 
	claimCollateral(e, collateralTokenId, amount1);
	claimCollateral(e, collateralTokenId, amount2);
	uint256 sum =  amount1 + amount2;
	additivityClaimableCollateral(collateralTokenId, sum, amount1 , amount2);
	uint256 balance1 = collateralToken.balanceOf(e.msg.sender, collateralTokenId); 
	
	claimCollateral(e, collateralTokenId, amount1 + amount2) at init_state;
	uint256 balance2 = collateralToken.balanceOf(e.msg.sender, collateralTokenId); 
	assert balance1 == balance2;
}

/* 	Rule: zeroCollateralZeroClaim
 	Description: claiming collateral having Zero collateral should result in Zero claimed
	Formula: { b = collateralToken.balanceOf(u, collateralTokenId) == 0  &&
			  c = getTokenBalanceOf(asset, address(this)) }
			 claimCollateral(collateralTokenId, amount);
			 { b = 0 => getTokenBalanceOf(asset, address(this) = c }
	Notes: 
*/
rule zeroCollateralZeroClaim(uint256 collateralTokenId, uint256 amount){
	env e;
	address qToken = collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId);
	require qToken == qTokenA;
	address asset = qTokenA.isCall() ? qTokenA.underlyingAsset() : qTokenA.strikeAsset();
	require asset != qToken;
	require ghost_claimableCollateral(collateralTokenId, amount) == quantCalculator.claimableCollateral(collateralTokenId, amount);
	
	uint balanceContractBefore = getTokenBalanceOf(e, asset, currentContract);
	uint balanceUserColBefore = collateralToken.balanceOf(e.msg.sender, collateralTokenId); 
	claimCollateral(e,collateralTokenId, amount);
	uint balanceContractAfter = getTokenBalanceOf(e, asset, currentContract);
	assert balanceUserColBefore == 0 => balanceContractBefore == balanceContractAfter;
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
function setupQtokenCollateralTokenId(address qTokenToMint, address qTokenForCollateral, uint collateralTokenId) {
	require qTokenToMint == collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId);
	require ghost_collateral(qTokenToMint,qTokenForCollateral) == collateralTokenId;
	address qToken_;
	address qTokenForCollateral_;
	qToken_, qTokenForCollateral_ = collateralToken.idToInfo(collateralTokenId);
	require qToken_ == qTokenToMint && qTokenForCollateral_ == qTokenForCollateral;
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
