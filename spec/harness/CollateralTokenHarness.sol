pragma solidity ^0.7.0;
pragma abicoder v2;

import "../../contracts/options/CollateralToken.sol";
    
contract CollateralTokenHarness is CollateralToken {    

    ////////////////////////////////////////////////////////////////////////////
    //                         Constructors and inits                         //
    ////////////////////////////////////////////////////////////////////////////
    constructor(address _quantConfig) CollateralToken(_quantConfig) public { }

    ////////////////////////////////////////////////////////////////////////////
    //                        Getters for The Internals                       //
    ////////////////////////////////////////////////////////////////////////////
    function getCollateralTokenId(uint tokenId) public view returns (uint256) {
        return collateralTokenIds[tokenId];
    }

	////////////////////////////////////////////////////////////////////////////
    //                       Simplifiers and override                         //
    ////////////////////////////////////////////////////////////////////////////
    /*function ...() public view returns (uint256) {
        return ...;
    }*/
}