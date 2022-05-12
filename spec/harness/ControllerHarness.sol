// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import "../../contracts/libraries/Actions.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../contracts/Controller.sol";
import "../../contracts/options/QToken.sol";
import "../../contracts/interfaces/IOptionsFactory.sol";

contract ControllerHarness is Controller {
    ////////////////////////////////////////////////////////////////////////////
    //                         Constructors and inits                         //
    ////////////////////////////////////////////////////////////////////////////
    constructor(
        string memory _name,
        string memory _version,
        string memory _uri,
        address _oracleRegistry,
        address _strikeAsset,
        address _priceRegistry,
        address _assetsRegistry,
        QToken _implementation
    )
        Controller(
            _name,
            _version,
            _uri,
            _oracleRegistry,
            _strikeAsset,
            _priceRegistry,
            _assetsRegistry,
            _implementation
        )
    {}

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
        return QToken(qToken).expiryTime();
    }
}
