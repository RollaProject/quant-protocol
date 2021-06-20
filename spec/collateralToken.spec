/*
    This is a specification file for smart contract verification with the Certora prover.
    For more information, visit: https://www.certora.com/

    This file is run with scripts/...
	Assumptions: 
*/

/*
    Declaration of contracts used in the spec 
*/
//using otherContractName as internalName

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

	//QuantConfig
	quantRoles(string) => DISPATCHER(true)
	hasRole(bytes32, address) => DISPATCHER(true)
}




////////////////////////////////////////////////////////////////////////////
//                       Ghost                                            //
////////////////////////////////////////////////////////////////////////////


ghost ghostBalances(uint256, address) returns uint256;

hook Sload uint256 balance _balances[KEY uint256 collateralTokenId][KEY address token] STORAGE {
    require ghostBalances(collateralTokenId, token) == balance;
}
hook Sstore _balances[KEY uint256 collateralTokenId][KEY address token] uint256 balance STORAGE {
    havoc ghostBalances assuming ghostBalances@new(collateralTokenId, token) == balance && (forall uint256 x. forall address y. x != collateralTokenId || y != token => ghostBalances@new(x, y) == ghostBalances@old(x, y));
}


////////////////////////////////////////////////////////////////////////////
//                       Invariants                                       //
////////////////////////////////////////////////////////////////////////////



/* 	Rule: Uniqueness collateralTokenIds    
 	Description:  Each entry in collateralTokenIds is unique
	Formula: collateralTokenIds[i] = collateralTokenIds[j] => i = j
*/


invariant uniqueCollateralTokenId(uint i, uint j)
	getCollateralTokenId(i) == getCollateralTokenId(j) => i == j

////////////////////////////////////////////////////////////////////////////
//                       Rules                                            //
////////////////////////////////////////////////////////////////////////////

/* 	Rule: Uniqueness collateralTokenIds    
 	Description:  Each entry in collateralTokenIds is unique
	Formula: collateralTokenIds[i] = collateralTokenIds[j] => i = j
*/
rule integrityOfCollateralTokenBalance(address _qTokenAddress, address _qTokenAsCollateral, address _recipient, uint256 _amount) {
	env e;
	uint collateralTokenInfoId;

	collateralTokenInfoId = createCollateralToken(e, _qTokenAddress, _qTokenAsCollateral);
	mintCollateralToken(e, _recipient, collateralTokenInfoId, _amount);

	assert ghostBalances(collateralTokenInfoId, _recipient) == _amount;
}

rule integrityOfCollateralTokenInfo(address _qTokenAddress, address _qTokenAsCollateral)
{
	env e;
	uint collateralTokenInfoId;

	collateralTokenInfoId = createCollateralToken(e, _qTokenAddress, _qTokenAsCollateral);

	assert(_qTokenAddress == getCollateralTokenInfoTokenAddress(collateralTokenInfoId) && _qTokenAsCollateral == getCollateralTokenInfoTokenAsCollateral(collateralTokenInfoId));
}

rule validityOfCollateralToken(address _qTokenAddress, address _qTokenAsCollateral)
{
	env e;
	uint i;
	uint collateralTokenInfoId;

	collateralTokenInfoId = createCollateralToken(e, _qTokenAddress, _qTokenAsCollateral);

	assert(idToInfoContainsId(collateralTokenInfoId) && collateralTokenIdsContainsId(collateralTokenInfoId, i));
}

rule validityOfMintedCollateralToken(address _qTokenAddress, address _qTokenAsCollateral, address _recipient, uint256 _amount)
{
	env e;
	uint256 collateralTokenInfoId;

	collateralTokenInfoId = createCollateralToken(e, _qTokenAddress, _qTokenAsCollateral);
	mintCollateralToken(e, _recipient, collateralTokenInfoId, _amount);

	assert(tokenSuppliesContainsCollateralToken(collateralTokenInfoId));
}

rule aMintedCollateralTokenCanBeBurned(address _qTokenAddress, address _qTokenAsCollateral, address _recipient, address _owner, uint256 _amount)
{
	env e;
	uint256 collateralTokenInfoId;

	collateralTokenInfoId = createCollateralToken(e, _qTokenAddress, _qTokenAsCollateral);
	mintCollateralToken(e, _recipient, collateralTokenInfoId, _amount);

	assert(tokenSuppliesContainsCollateralToken(collateralTokenInfoId));

	burnCollateralToken(e, _owner, collateralTokenInfoId, _amount);

	assert(!tokenSuppliesContainsCollateralToken(collateralTokenInfoId));
}
////////////////////////////////////////////////////////////////////////////
//                       Helper Functions                                 //
////////////////////////////////////////////////////////////////////////////
// easy to use dispatcher
/*function callFunctionWithParams(address token, address from, address to,
 								uint256 amount, uint256 share, method f) {
	env e;

	if (f.selector == deposit(address, address, address, uint256, uint256).selector) {
		deposit(e, token, from, to, amount, share);
	} else if (f.selector == withdraw(address, address, address, uint256, uint256).selector) {
		withdraw(e, token, from, to, amount, share); 
	} else if  (f.selector == transfer(address, address, address, uint256).selector) {
		transfer(e, token, from, to, share);
	} else {
		calldataarg args;
		f(e,args);
	}
}*/