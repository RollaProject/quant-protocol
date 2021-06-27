/*
    This is a specification file for smart contract verification with the Certora prover.
    For more information, visit: https://www.certora.com/

    This file is run with spec/scripts/runCollateralToken.sh

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
	getCollateralTokenId(uint) returns uint envfree
	getCollateralTokenInfoTokenAddress(uint) returns address envfree
	getCollateralTokenInfoTokenAsCollateral(uint) returns address envfree
	idToInfoContainsId(uint) returns bool envfree
	collateralTokenIdsContainsId(uint, uint) returns bool envfree
	tokenSuppliesContainsCollateralToken(uint) returns bool envfree
	tokenSupplies(uint) returns uint envfree
	getCollateralTokensLength() returns uint envfree
	balanceOf(address,uint)returns uint envfree

	//QuantConfig
	quantRoles(string) => NONDET
	hasRole(bytes32, address) => NONDET
}




////////////////////////////////////////////////////////////////////////////
//                       Ghost                                            //
////////////////////////////////////////////////////////////////////////////



// the sum of all u. balances(cid,u)
ghost sumBalances(uint256) returns uint256;

hook Sstore _balances[KEY uint256 collateralTokenId][KEY address user] uint256 balance (uint256 oldBalance) STORAGE {
    havoc sumBalances assuming sumBalances@new(collateralTokenId) == sumBalances@old(collateralTokenId) + balance - oldBalance && (forall uint256 x.  x != collateralTokenId  => sumBalances@new(x) == sumBalances@old(x));
}
/*
hook Sload uint256 balance _balances[KEY uint256 collateralTokenId][KEY address user] STORAGE {
    require sumBalances(collateralTokenId) >= balance;
}
*/





////////////////////////////////////////////////////////////////////////////
//                       Invariants                                       //
////////////////////////////////////////////////////////////////////////////

/* 	Rule: TotalSupply is the sum of balances    
 	Description:  Each entry in collateralTokenIds is unique
	Formula: totalSupplies[collateralTokenId] = sum _balances[collateralTokenId][x] for all x
*/
invariant sumBalancesVsTotalSupplies(uint collateralTokenId)
	sumBalances(collateralTokenId) == tokenSupplies(collateralTokenId) 
	{
		preserved burnCollateralTokenBatch(address a,uint256[] b,uint256[] c) with (env e){
			require false;
		} 
		preserved mintCollateralTokenBatch(address a,uint256[] b,uint256[] c) with (env e){
			require false;
		} 

	}



/* 	Rule: Uniqueness collateralTokenIds    
 	Description:  Each entry in collateralTokenIds is unique
	Formula: collateralTokenIds[i] = collateralTokenIds[j] => i = j
*/
invariant uniqueCollateralTokenId(uint i, uint j)
	getCollateralTokenId(i) == getCollateralTokenId(j) => i == j


////////////////////////////////////////////////////////////////////////////
//                       Rules                                            //
////////////////////////////////////////////////////////////////////////////



/* 	Rule: Integrity of collateralTokenInfo    
 	Description:  Creating a new pair of QTokens creates the collateralTokenInfo
	Formula: { } 
			collateralTokenInfoId = createCollateralToken(qTokenAddress, qTokenAsCollateral)
			{ (qTokenAddress, qTokenAsCollateral) = getCollateralTokenInfo(collateralTokenInfoId) }
*/
rule integrityOfCollateralTokenInfo(address _qTokenAddress, address _qTokenAsCollateral)
{
	env e;
	uint collateralTokenInfoId;

	collateralTokenInfoId = createCollateralToken(e, _qTokenAddress, _qTokenAsCollateral);

	assert(_qTokenAddress == getCollateralTokenInfoTokenAddress(collateralTokenInfoId) && _qTokenAsCollateral == getCollateralTokenInfoTokenAsCollateral(collateralTokenInfoId));
}

/* 	Rule: Integrity of collateralToken 
 	Description:  Each collateralToken has an entry in  the collateralTokenInfo
	Formula: { i = collateralTokenIds.length } 
			collateralTokenInfoId = createCollateralToken(qToken, qTokenAsCollateral)
			{ idToInfo[collateralTokenInfoId].qTokenAddress != 0 && collateralTokenIds[i] == key }
*/
rule validityOfCollateralToken(address _qTokenAddress, address _qTokenAsCollateral)
{
	env e;
	uint i = getCollateralTokensLength();
	uint collateralTokenInfoId;

	require _qTokenAddress != 0;
	collateralTokenInfoId = createCollateralToken(e, _qTokenAddress, _qTokenAsCollateral);

	assert(idToInfoContainsId(collateralTokenInfoId) && collateralTokenIdsContainsId(collateralTokenInfoId, i));
}

/* 	Rule: Integrity of minting 
 	Description:  On minting x the balance is updated by x
	Formula: { before = balanceOf(_recipient, collateralTokenInfoId) } 
			mintCollateralToken(e, recipient, collateralTokenInfoId, amount);
			{ balanceOf(recipient, collateralTokenInfoId) = amount + b}
*/
rule integrityOfMinting(address _qTokenAddress, address _qTokenAsCollateral, address _recipient, uint256 _amount) {
	env e;
	uint collateralTokenInfoId;

	uint256 before = balanceOf(_recipient, collateralTokenInfoId);
	
	mintCollateralToken(e, _recipient, collateralTokenInfoId, _amount);

	assert balanceOf(_recipient, collateralTokenInfoId) == before + _amount;
}


/* 	Rule: Integrity of token supply on Minting 
 	Description:  Once minting, the collateralToken has an entry in the tokenSupplies array
	Formula: { amount > 0 } 
			collateralTokenInfoId = createCollateralToken(qToken, qTokenAsCollateral);
			mintCollateralToken(e, _recipient, collateralTokenInfoId, _amount);
			{ tokenSupplies[collateralTokenInfoId] != 0 }
*/
rule integrityOfTotalSupplyOnMinting(address _qTokenAddress, address _qTokenAsCollateral, address _recipient, uint256 _amount)
{
	env e;
	uint256 collateralTokenInfoId;
	require _amount > 0;
	collateralTokenInfoId = createCollateralToken(e, _qTokenAddress, _qTokenAsCollateral);
	mintCollateralToken(e, _recipient, collateralTokenInfoId, _amount);

	assert(tokenSuppliesContainsCollateralToken(collateralTokenInfoId));
}


/* 	Rule: Burn after mint 
 	Description:  Once minting, the collateralToken can be burned
	Formula: {before = balanceOf(user, collateralTokenInfoId)  } 
				mintCollateralToken(user, collateralTokenInfoId, _amount);
				burnCollateralToken(user, collateralTokenInfoId, _amount);
			{ balanceOf(user, collateralTokenInfoId) = before }
*/
rule aMintedCollateralTokenCanBeBurned(address _qTokenAddress, address _qTokenAsCollateral, address _recipient, address _owner, uint256 _amount)
{
	env e;
	uint256 collateralTokenInfoId;

	uint256 before = balanceOf(e.msg.sender, collateralTokenInfoId);
	mintCollateralToken(e, e.msg.sender, collateralTokenInfoId, _amount);
	burnCollateralToken(e, e.msg.sender, collateralTokenInfoId, _amount);
	assert before == balanceOf(e.msg.sender, collateralTokenInfoId);
}
