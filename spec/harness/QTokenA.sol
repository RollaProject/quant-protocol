// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import "./QTokenCore.sol";

contract QTokenA is QTokenCore {
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
        public
        QTokenCore(
            _underlyingAsset,
            _strikeAsset,
            _priceRegistry,
            _assetsRegistry,
            _oracle,
            _expiryTime,
            _isCall,
            _strikePrice
        )
    {}
}
