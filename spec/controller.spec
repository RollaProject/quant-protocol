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
	optionsFactory.isQToken(address _qToken) returns (bool) envfree


	// CollateralToken
	mintCollateralToken(address,uint256,address,uint256) => NONDET
	burnCollateralToken(address,uint256,uint256) => NONDET
	balanceOf(address, uint256) => NONDET
	getCollateralTokenId(uint256) => DISPATCHER(true)
	collateralToken.getTokenSupplies(uint) returns (uint) envfree
	//getCollateralTokenInfoTokenAddress(uint256) returns (address)  => DISPATCHER(true)
    collateralToken.getCollateralTokenInfoTokenAddress(uint) returns (address) envfree
}



////////////////////////////////////////////////////////////////////////////
//                       Ghost                                            //
////////////////////////////////////////////////////////////////////////////


// Ghosts are like additional function
// sumDeposits(address user) returns (uint256);
// This ghost represents the sum of all deposits to user
// sumDeposits(s) := sum(...[s].deposits[member] for all addresses member)




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
rule validQtoken(  method f )  
{
	address qToken; 
	address qTokenFroCollateral;
	uint256 collateralTokenId;
	address to;
	uint256 amount;
	
	callFunctionWithParams(qToken, qTokenFroCollateral, collateralTokenId, to, amount, f);
	assert optionsFactory.isQToken(qToken);   
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


rule only_after_expiry(method f)
	filtered { f-> f.selector == claimCollateral(uint256, uint256).selector ||
			 	f.selector == exercise(address,uint256).selector }
{
	env e;
	address qToken; 
	uint256 collateralTokenId;
	uint256 amount;

	if (f.selector == exercise(address,uint256).selector) {
		exercise(e, qToken, amount);
	}
	else if (f.selector == claimCollateral(uint256,uint256).selector ) {
		require qToken == collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId);
    	claimCollateral(e, collateralTokenId, amount);
	}
	assert e.block.timestamp > getExpiryTime(e,qToken);
}

rule additive_claim(uint256 collateralTokenId, uint256 amount1, uint256 amount2){
	env e;
	uint256 balance1;
	uint256 balance2;
	storage init_state = lastStorage;
	claimCollateral(e, collateralTokenId, amount1);
	claimCollateral(e, collateralTokenId, amount2);
	balance1 = balanceOfCol(e,collateralTokenId,e.msg.sender);
	claimCollateral(e, collateralTokenId, amount1 + amount2) at init_state;
	balance2 = balanceOfCol(e, collateralTokenId, e.msg.sender);
	assert balance1 == balance2;
}
rule ratio_after_neutralize(uint256 collateralTokenId, uint256 amount, address qToken){
	env e;
	require qToken == collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId);
	require qToken == qTokenA ; 
	uint256 totalSupllyTBefore = qTokenA.totalSupply();
	uint256 totalSupllyCBefore = collateralToken.getTokenSupplies(collateralTokenId);
	neutralizePosition(e, collateralTokenId, amount);
	uint256 totalSupllyTAfter = qTokenA.totalSupply();
	uint256 totalSupllyCAfter = collateralToken.getTokenSupplies(collateralTokenId);
	assert  totalSupllyTAfter - totalSupllyTBefore == totalSupllyCAfter - totalSupllyCBefore;
	
}


/*  Rule: Mint Options QToken Correctness
		formula: mintOptionsPosition(to,qToken,amount) =>
				qToken.balanceOf(to) == qToken.balanceOf(to) + amount &&
				qToken.totalSupply() == qToken.totalSupply() + amount &&
				collateralToken.balanceOf(to,tokenId) == collateralToken.balanceOf(to,tokenId) + amount &&
				collateralToken.tokenSupplies(tokenId) == collateralToken.tokenSupplies(tokenId) + amount;
*/
rule MintOptionsCorrectness(uint collateralTokenId, uint amount){
	env e;
	address qToken = qTokenA;
	require qToken == collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId);
	uint balanceOfqTokenBefore = qTokenA.balanceOf(e,e.msg.sender);
	uint totalSupplyqTokenBefore = qTokenA.totalSupply();
	uint balanceOfcolTokenBefore = balanceOfCol(e,collateralTokenId,e.msg.sender);
	uint totalSupplyOfcolTokenBefore = collateralToken.getTokenSupplies(collateralTokenId);
		mintOptionsPosition(e,e.msg.sender,qTokenA,amount);
	uint balanceOfqTokenAfter = qTokenA.balanceOf(e,e.msg.sender);
	uint totalSupplyqTokenAfter = qTokenA.totalSupply();
	uint balanceOfcolTokenAfter = balanceOfCol(e,collateralTokenId,e.msg.sender);
	uint totalSupplyOfcolTokenAfter = collateralToken.getTokenSupplies(collateralTokenId);
	assert (balanceOfqTokenAfter == balanceOfqTokenBefore + amount &&
		   totalSupplyqTokenAfter == totalSupplyqTokenBefore + amount &&
		   balanceOfcolTokenAfter == balanceOfcolTokenBefore + amount &&
		   totalSupplyOfcolTokenAfter == totalSupplyOfcolTokenBefore + amount);
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
	uint    balanceControlerBefore = balanceOfCol(e, collateralTokenId,thisContract(e)); // address(this));
	uint    balanceUserBefore = balanceOfCol(e, collateralTokenId, e.msg.sender);
	mintOptionsPosition(e,e.msg.sender, qTokenA, amount);
	uint    balanceControlerAfter = balanceOfCol(e,collateralTokenId, thisContract(e));// address(this));
	uint    balanceUserAfter = balanceOfCol(e,collateralTokenId, e.msg.sender);
	assert (balanceControlerAfter - balanceControlerBefore ==
			balanceUserBefore - balanceUserAfter);
}

/*
rule colToken_Impl_ColDeposited(uint256 collateralTokenId, address user){
uint colAmount = balanceOfCol(e,collateralTokenId,user);
}*/

rule solvencyUser(uint collateralTokenId){
	env e;
	address qToken = collateralToken.getCollateralTokenInfoTokenAddress(collateralTokenId);
	require qToken == qTokenA;
	uint balanceUserBefore = qTokenA.balanceOf(e,e.msg.sender);
	uint balanceColBefore = balanceOfCol(e,collateralTokenId,e.msg.sender);
	method f;
	calldataarg args;
	f(e,args);
	uint balanceUserAfter = qTokenA.balanceOf(e,e.msg.sender);
	uint balanceColAfter = balanceOfCol(e,collateralTokenId,e.msg.sender);
	assert (balanceUserBefore + balanceColBefore == balanceUserAfter + balanceColAfter);
}

////////////////////////////////////////////////////////////////////////////
//                       Helper Functions                                 //
////////////////////////////////////////////////////////////////////////////
    

// easy to use dispatcher

function callFunctionWithParams(address qToken, address qTokenFroCollateral, uint256 collateralTokenId, address to, uint256 amount, method f) {
	env e;

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
