// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma abicoder v2;	
    

import "../../contracts/libraries/Actions.sol";
import "../../contracts/Controller.sol";
contract ControllerHarness is Controller {
    ////////////////////////////////////////////////////////////////////////////
    //                         Constructors and inits                         //
    ////////////////////////////////////////////////////////////////////////////
    //constructor( ) .. public { }

    ////////////////////////////////////////////////////////////////////////////
    //                        Getters for The Internals                       //
    ////////////////////////////////////////////////////////////////////////////
    /*function get...() public view returns (uint256) {
        return ...;
    }*/

	////////////////////////////////////////////////////////////////////////////
    //                       Simplifiers and override                         //
    ////////////////////////////////////////////////////////////////////////////
    function mintOptionsPosition(address to, address qToken, uint256 amount) 
        public  {
            
            Actions.MintOptionArgs memory args = Actions.MintOptionArgs({
                to:to,
                qToken: qToken,
                amount: amount
             });
            _mintOptionsPosition(args);
    }



   function mintSpread(address qToken, address qTokenForCollateral, uint256 amount) 
        public  {
            
           Actions.MintSpreadArgs memory args = Actions.MintSpreadArgs({
                qTokenToMint: qToken,
                qTokenForCollateral: qTokenForCollateral,
                amount: amount
            });


    }

    //TODO - continue other functions


    // TODO - override initialize and operate

    

}