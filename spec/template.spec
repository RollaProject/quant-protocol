/*
    This is a specification file for smart contract verification with the Certora prover.
    For more information, visit: https://www.certora.com/

    This file is run with scripts/...
	Assumptions: 
*/

/*
    Declaration of contracts used in the spec 
*/
using otherContractName as internalName


////////////////////////////////////////////////////////////////////////////
//                      Methods                                           //
////////////////////////////////////////////////////////////////////////////


/*
    Declaration of methods that are used in the rules.
    envfree indicate that the method is not dependent on the environment (msg.value, msg.sender).
    Methods that are not declared here are assumed to be dependent on env.
*/

methods {

}



////////////////////////////////////////////////////////////////////////////
//                       Ghost                                            //
////////////////////////////////////////////////////////////////////////////


// Ghosts are like additional function
// sumDeposits(address user) returns (uint256);
// This ghost represents the sum of all deposits to user
// sumDeposits(s) := sum(...[s].deposits[member] for all addresses member)

ghost sumDeposits(uint256) returns uint {
    init_state axiom forall uint256 s. sumDeposits(s) == 0;
}




// whenever there ia an update to
//     contractmap[user].deposits[memberAddress] := value
// where previously contractmap[user].deposits[memberAddress] was old_value
// update sumDeposits := sumDeposits - old_value + value
hook Sstore contractmap[KEY uint256 s].(offset 0)[KEY uint256 member] uint value (uint old_value) STORAGE {
    havoc sumDeposits assuming sumDeposits@new(s) == sumDeposits@old(s) + value - old_value &&
            (forall uint256 other. other != s => sumDeposits@new(other) == sumDeposits@old(other));
}



////////////////////////////////////////////////////////////////////////////
//                       Invariants                                       //
////////////////////////////////////////////////////////////////////////////



/* 	Rule: title  
 	Description:  
	Formula: 
	Notes: assumptions and simplification more explanations 
*/


function validState(...) {

} 

////////////////////////////////////////////////////////////////////////////
//                       Rules                                            //
////////////////////////////////////////////////////////////////////////////
    



////////////////////////////////////////////////////////////////////////////
//                       Helper Functions                                 //
////////////////////////////////////////////////////////////////////////////
    

// easy to use dispatcher
function callFunctionWithParams(address token, address from, address to,
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
}