// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../../contracts/libraries/Actions.sol";
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
        Controller(_name, _version, _uri, _oracleRegistry, _strikeAsset, _priceRegistry, _assetsRegistry, _implementation)
    {}

    ////////////////////////////////////////////////////////////////////////////
    //                        Getters for The Internals                       //
    ////////////////////////////////////////////////////////////////////////////

    function getTokenBalanceOf(address t, address u) public view returns (uint256) {
        return IERC20(t).balanceOf(u);
    }

    function operate(ActionArgs[] memory _actions) external override {}

    function _msgSender() internal view override returns (address sender) {
        return msg.sender;
    }

    function getExpiryTime(address qToken) public view returns (uint256) {
        return QToken(qToken).expiryTime();
    }
}
