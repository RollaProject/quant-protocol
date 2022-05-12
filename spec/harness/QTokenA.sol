// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import "./QTokenCore.sol";

contract QTokenA is QTokenCore {
    constructor(
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice,
        address _controller
    )
        QTokenCore(
            _underlyingAsset,
            _strikeAsset,
            _oracle,
            _expiryTime,
            _isCall,
            _strikePrice,
            _controller
        )
    {}
}
