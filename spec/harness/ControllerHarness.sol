// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma abicoder v2;

import "../../contracts/libraries/Actions.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../contracts/Controller.sol";

contract ControllerHarness is Controller {
    ////////////////////////////////////////////////////////////////////////////
    //                         Constructors and inits                         //
    ////////////////////////////////////////////////////////////////////////////
    //constructor( ) .. public { }

    ////////////////////////////////////////////////////////////////////////////
    //                        Getters for The Internals                       //
    ////////////////////////////////////////////////////////////////////////////
   
    function getTokenBalanceOf(address t, address u) public view returns (uint256) {
        return IERC20(t).balanceOf(u);
    }

    function isValidQToken(address _qToken) public returns(bool) {
            return IOptionsFactory(optionsFactory).isQToken(_qToken);
    }

    ////////////////////////////////////////////////////////////////////////////
    //                       Simplifiers and override                         //
    ////////////////////////////////////////////////////////////////////////////
    function mintOptionsPosition(
        address to,
        address qToken,
        uint256 amount
    ) public {
        Actions.MintOptionArgs memory args =
            Actions.MintOptionArgs({
                to: to, 
                qToken: qToken, 
                amount: amount
            });
        _mintOptionsPosition(args);
    }

    function mintSpread(
        address qToken,
        address qTokenForCollateral,
        uint256 amount
    ) public {
        Actions.MintSpreadArgs memory args =
            Actions.MintSpreadArgs({
                qTokenToMint: qToken,
                qTokenForCollateral: qTokenForCollateral,
                amount: amount
            });
        _mintSpread(args);
    }


    function exercise(
        address qToken,
        uint256 amount
    ) public {
        Actions.ExerciseArgs memory args = 
            Actions.ExerciseArgs({
                qToken: qToken, 
                amount: amount
            });
        _exercise(args);
    }

    //TODO - continue other functions

    // TODO - override initialize and operate
}
