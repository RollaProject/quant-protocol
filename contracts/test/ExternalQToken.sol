// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import "../options/QToken.sol";

contract ExternalQToken is QToken {
    constructor(
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        address _priceRegistry,
        address _assetsRegistry,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    )
        QToken(
            _underlyingAsset,
            _strikeAsset,
            _oracle,
            _priceRegistry,
            _assetsRegistry,
            _strikePrice,
            _expiryTime,
            _isCall
        )
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function permissionlessMint(address account, uint256 amount) external {
        _mint(account, amount);
        emit QTokenMinted(account, amount);
    }
}
