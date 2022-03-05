// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.12;

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
        _mintOptionsPosition(to, qToken, amount);
    }

    function mintSpread(
        address qToken,
        address qTokenForCollateral,
        uint256 amount
    ) public {
        _mintSpread(qToken, qTokenForCollateral, amount);
    }

    function exercise(address qToken, uint256 amount) public {
        _exercise(qToken, amount);
    }

    function claimCollateral(uint256 collateralTokenId, uint256 amount) public {
        _claimCollateral(collateralTokenId, amount);
    }

    function neutralizePosition(uint256 collateralTokenId, uint256 amount)
        public
    {
        _neutralizePosition(collateralTokenId, amount);
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
