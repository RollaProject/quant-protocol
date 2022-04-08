// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import "./QTokenCore.sol";

contract QTokenA is QTokenCore {
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
        public
        QTokenCore(
            _underlyingAsset,
            _strikeAsset,
            _oracle,
            _priceRegistry,
            _assetsRegistry,
            _strikePrice,
            _expiryTime,
            _isCall
        )
    {}
}
