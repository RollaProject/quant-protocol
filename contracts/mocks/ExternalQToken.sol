// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.14;

import "../options/QToken.sol";

contract ExternalQToken is QToken {
    function permissionlessMint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
