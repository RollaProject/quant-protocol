// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.0;
pragma abicoder v2;

import "../../contracts/libraries/Actions.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../contracts/Controller.sol";
import "../../contracts/interfaces/IQToken.sol";
import "../../contracts/interfaces/IOptionsFactory.sol";

contract ControllerHarness is Controller {
    ////////////////////////////////////////////////////////////////////////////
    //                         Constructors and inits                         //
    ////////////////////////////////////////////////////////////////////////////
    //constructor( ) .. public { }

    ////////////////////////////////////////////////////////////////////////////
    //                        Getters for The Internals                       //
    ////////////////////////////////////////////////////////////////////////////

    function getTokenBalanceOf(address t, address u)
        public
        view
        returns (uint256)
    {
        return IERC20(t).balanceOf(u);
    }

    ////////////////////////////////////////////////////////////////////////////
    //                       Each operation wrapper                           //
    ////////////////////////////////////////////////////////////////////////////
    function mintOptionsPosition(
        address to,
        address qToken,
        uint256 amount
    ) public {
        Actions.MintOptionArgs memory args =
            Actions.MintOptionArgs({to: to, qToken: qToken, amount: amount});
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

    function exercise(address qToken, uint256 amount) public {
        Actions.ExerciseArgs memory args =
            Actions.ExerciseArgs({qToken: qToken, amount: amount});
        _exercise(args);
    }

    function claimCollateral(uint256 collateralTokenId, uint256 amount) public {
        Actions.ClaimCollateralArgs memory args =
            Actions.ClaimCollateralArgs({
                collateralTokenId: collateralTokenId,
                amount: amount
            });
        _claimCollateral(args);
    }

    function neutralizePosition(uint256 collateralTokenId, uint256 amount)
        public
    {
        Actions.NeutralizeArgs memory args =
            Actions.NeutralizeArgs({
                collateralTokenId: collateralTokenId,
                amount: amount
            });
        _neutralizePosition(args);
    }

    function operate(ActionArgs[] memory _actions)
        external
        override
        nonReentrant
        returns (bool)
    {}

    function _msgSender() internal view override returns (address sender) {
        return msg.sender;
    }

    function getExpiryTime(address qToken) public view returns (uint256) {
        return IQToken(qToken).expiryTime();
    }
}
