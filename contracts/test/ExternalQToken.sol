// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import "../options/QToken.sol";

contract ExternalQToken is QToken {
    constructor(
        address _underlyingAsset,
        address _strikeAsset,
        address _priceRegistry,
        address _assetsRegistry,
        address _oracle,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice
    )
        QToken(
            _underlyingAsset,
            _strikeAsset,
            _priceRegistry,
            _assetsRegistry,
            _oracle,
            _expiryTime,
            _isCall,
            _strikePrice
        )
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function permissionlessMint(address account, uint256 amount) external {
        _mint(account, amount);
        emit QTokenMinted(account, amount);
    }
}
