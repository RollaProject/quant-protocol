// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "./QTokenCore.sol";

contract QTokenA is QTokenCore {
    constructor(
        address _quantConfig,
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    )
        public
        QTokenCore(
            _quantConfig,
            _underlyingAsset,
            _strikeAsset,
            _oracle,
            _strikePrice,
            _expiryTime,
            _isCall
        )
    {}
}
