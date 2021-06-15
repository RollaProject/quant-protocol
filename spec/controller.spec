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
	balanceOf(address) => DISPATCHER(true) 
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
	quantCalculator.qTokenToCollateralType(address) returns (address) envfree
	collateralToken.getTokenSupplies(uint) returns (uint) envfree
	//getCollateralTokenInfoTokenAddress(uint256) returns (address)  => DISPATCHER(true)
    collateralToken.getCollateralTokenInfoTokenAddress(uint) returns (address) envfree
	collateralToken.getCollateralTokenInfoTokenAsCollateral(uint)returns (address) envfree
	collateralToken.balanceOf(address, uint256) returns (uint256) envfree => DISPATCHER(true)

	// Computations
	getNeutralizationPayout(address,address,uint256,address) => NONDET 


	//ERC1155Receiver
	onERC1155Received(address,address,uint256,uint256,bytes) => NONDET


}



////////////////////////////////////////////////////////////////////////////
//                       Ghost                                            //
////////////////////////////////////////////////////////////////////////////


// Ghosts are like additional function
// sumDeposits(address user) returns (uint256);
// This ghost represents the sum of all deposits to user
// sumDeposits(s) := sum(...[s].deposits[member] for all addresses member)

// A ghost to represent the uniqueness of collateralTokenId for each pair of qTokens
ghost ghost_collateral(address , address) returns uint; //`{
	//axiom forall uint256 p1. forall uint256 q1. forall uint256 p2. forall uint256 q2.
    //     (p1 != p2 || q1 != q2)  => ghost_collateral(p1,q1) != ghost_collateral(p2,q2);
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
    
/* 	Rule: validQToken  
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
	assert collateralAsset == qtoken || collateralAsset == collateralTokenId; 
 }*/

// 1.  _claimCollateral(Actions.ClaimCollateralArgs memory _args)
//    the more the user claim the less his balance of collateral tokens
// 2. claim(x) + claim(y) == claim(x+y)
// 3. claim(x) <= balanceOf(x)
/*
rule solvency(uint256 collateralTokenId,uint256 amount){
	env e;
	require _args.collateralTokenId == collateralTokenId;
	require _args.amount == amount;
	address Ctoken = getCollateralTokenInfoTokenAddress(collateralTokenId);
	getCollateralTokenInfoTokenAddress
	_claimCollateral(Actions.ClaimCollateralArgs memory _args);
	assert !lastreverted;
}*/


rule only_after_expiry(method f, bool eitherClaimOrExercise)
	
{
	env e;
	address qToken; 
	uint256 collateralTokenId;
	uint256 amount;
	uint256 expiry = getExpiryTime(e,qToken);

	//if (eitherClaimOrExercise) {
		exercise(e, qToken, amount);
	//}
	/*else {
		require qToken == collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId);
    	claimCollateral(e, collateralTokenId, amount);
	} */
	assert e.block.timestamp > expiry;
}

rule additive_claim(uint256 collateralTokenId, uint256 amount1, uint256 amount2){
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



rule ratio_after_neutralize(uint256 collateralTokenId, uint256 amount, address qToken){
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
rule MintOptionsCorrectness(uint256 collateralTokenId, uint amount){
	env e;
	address qToken = qTokenA;
	//address qTokenLong = 0;
	//require collateralTokenId == collateralToken.getCollateralTokenId(qToken, qTokenLong);
	require qToken == collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId);
	//require quantCalculator.qTokenToCollateralType(qToken) == collateralToken;
	require ghost_collateral(qToken,0) == collateralTokenId;
	require qTokenA.isCall(e);
	uint balanceOfqTokenBefore = qTokenA.balanceOf(e,e.msg.sender);
	uint totalSupplyqTokenBefore = qTokenA.totalSupply();
	uint balanceOfcolTokenBefore = collateralToken.balanceOf(e.msg.sender, collateralTokenId); 
	uint totalSupplyColTokenBefore = collateralToken.getTokenSupplies(collateralTokenId);
	require balanceOfqTokenBefore <= totalSupplyqTokenBefore &&
			balanceOfcolTokenBefore <= totalSupplyColTokenBefore;
		mintOptionsPosition(e,e.msg.sender,qTokenA,amount);
	uint balanceOfqTokenAfter = qTokenA.balanceOf(e,e.msg.sender);
	uint totalSupplyqTokenAfter = qTokenA.totalSupply();
	uint balanceOfcolTokenAfter = collateralToken.balanceOf(e.msg.sender, collateralTokenId);
	uint totalSupplyColTokenAfter = collateralToken.getTokenSupplies(collateralTokenId);
	require balanceOfqTokenAfter <= totalSupplyqTokenAfter &&
			balanceOfcolTokenAfter <= totalSupplyColTokenAfter;
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
rule MintOptionsColCorrectness(uint collateralTokenId, uint amount){
	env e;
	address qToken = collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId);
	require qToken == qTokenA;
	address asset = qTokenA.isCall(e) ? qTokenA.underlyingAsset(e) : qTokenA.strikeAsset(e);
	uint    balanceControlerBefore = 0;//IQToken(asset).balanceOf(e,currentContract);
	uint    balanceUserBefore = collateralToken.balanceOf(e.msg.sender, collateralTokenId); 
	mintOptionsPosition(e, e.msg.sender, qTokenA, amount);
	uint    balanceControlerAfter = 0;//IQToken(asset).balanceOf(e,currentContract);
	uint    balanceUserAfter = collateralToken.balanceOf(e.msg.sender, collateralTokenId);
	assert (balanceControlerAfter - balanceControlerBefore ==
			balanceUserBefore - balanceUserAfter);
}

/*
rule colToken_Impl_ColDeposited(uint256 collateralTokenId, address user){
uint colAmount = balanceOfCol(e,collateralTokenId,user);
}*/

rule solvencyUser(uint collateralTokenId, method f){
	env e;
	address qTokenFroCollateral;
	address to;
	uint256 amount;
	
	address qToken = collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId);
	require qToken == qTokenA;
	require ghost_collateral(qToken,0) == collateralTokenId;
	require qTokenA.isCall(e);
	address asset = qTokenA.underlyingAsset(e);
	require e.msg.sender != currentContract;//check if allowed
	uint balanceUserBefore = getTokenBalanceOf(e,asset,e.msg.sender);
	uint balanceColBefore = collateralToken.balanceOf(e.msg.sender, collateralTokenId); 

	//callFunctionWithParams(e.msg.sender, qToken, qTokenFroCollateral, collateralTokenId, to, amount, f);
	mintOptionsPosition(e,e.msg.sender,qTokenA,amount);

	uint balanceUserAfter = getTokenBalanceOf(e,asset,e.msg.sender);
	uint balanceColAfter = collateralToken.balanceOf(e.msg.sender, collateralTokenId); 
	assert (balanceUserBefore + balanceColBefore == balanceUserAfter + balanceColAfter +1);
}


/* 
	Rule: Inverse

	minting (simple or spread) and then neutralize are inverse


	minting and then claimCollateral and exercise are inverse  (also fro spread?)

*/

////////////////////////////////////////////////////////////////////////////
//                       Helper Functions                                 //
////////////////////////////////////////////////////////////////////////////
    

// easy to use dispatcher

function callFunctionWithParams(address expectedSender, address qToken, address qTokenFroCollateral, uint256 collateralTokenId, address to, uint256 amount, method f) {
	env e;
	require e.msg.sender == expectedSender;

	if (f.selector == exercise(address,uint256).selector) {
		exercise(e, qToken, amount);
	}
	else if (f.selector == mintOptionsPosition(address,address,uint256).selector) {
		mintOptionsPosition(e, to, qToken, amount); 
	} 
	else if (f.selector == mintSpread(address,address,uint256).selector) {
		mintSpread(e, qToken, qTokenFroCollateral, amount);
	}
	else if (f.selector == exercise(address,uint256).selector) {
		exercise(e, qToken, amount);
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
