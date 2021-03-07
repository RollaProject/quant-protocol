// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../QuantConfig.sol";

contract Whitelist {
    QuantConfig private _quantConfig;

    mapping(address => uint8) public whitelistedUnderlyingDecimals;

    constructor(address quantConfig_) {
        _quantConfig = QuantConfig(quantConfig_);
    }

    function whitelistUnderlying(address _underlying, uint8 _decimals)
        external
    {
        require(
            _quantConfig.hasRole(
                _quantConfig.OPTIONS_CONTROLLER_ROLE(),
                msg.sender
            ),
            "Whitelist: only admins can whitelist underlying tokens"
        );

        whitelistedUnderlyingDecimals[_underlying] = _decimals;
    }

    function blacklistUnderlying(address _underlying) external {
        require(
            _quantConfig.hasRole(
                _quantConfig.OPTIONS_CONTROLLER_ROLE(),
                msg.sender
            ),
            "Whitelist: only admins can blacklist underlying tokens"
        );

        whitelistedUnderlyingDecimals[_underlying] = 0;
    }
}
