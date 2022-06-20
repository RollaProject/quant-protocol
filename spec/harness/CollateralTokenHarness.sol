pragma solidity 0.8.15;

import "../../contracts/options/CollateralToken.sol";

contract CollateralTokenHarness is CollateralToken {
    ////////////////////////////////////////////////////////////////////////////
    //                         Constructors and inits                         //
    ////////////////////////////////////////////////////////////////////////////
    constructor()
        CollateralToken("", "", "https://tokens.rolla.finance/{id}.json")
    {}

    ////////////////////////////////////////////////////////////////////////////
    //                        Getters for The Internals                       //
    ////////////////////////////////////////////////////////////////////////////
    function getCollateralTokenInfoTokenAddress(uint256 collateralTokenInfoId)
        public
        view
        returns (address)
    {
        return idToInfo[collateralTokenInfoId].qTokenAddress;
    }

    function getCollateralTokenInfoTokenAsCollateral(
        uint256 collateralTokenInfoId
    ) public view returns (address) {
        return idToInfo[collateralTokenInfoId].qTokenAsCollateral;
    }

    function idToInfoContainsId(uint256 key) public view returns (bool) {
        if (idToInfo[key].qTokenAddress == address(0)) {
            return false;
        }
        return true;
    }

    function tokenSuppliesContainsCollateralToken(uint256 key)
        public
        view
        returns (bool)
    {
        if (tokenSupplies[key] == uint256(0)) {
            return false;
        }
        return true;
    }

    function getTokenSupplies(uint256 key) public view returns (uint256) {
        return tokenSupplies[key];
    }

    ////////////////////////////////////////////////////////////////////////////
    //                       Simplifiers and override                         //
    ////////////////////////////////////////////////////////////////////////////
    /*function ...() public view returns (uint256) {
        return ...;
    }*/
}
