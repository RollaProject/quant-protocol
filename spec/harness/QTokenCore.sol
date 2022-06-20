// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

import "../../contracts/options/QToken.sol";

contract QTokenCore is QToken {
    address public immutable override underlyingAsset;
    address public immutable override strikeAsset;
    address public immutable override oracle;
    uint88 public immutable override expiryTime;
    bool public immutable override isCall;
    uint256 public immutable override strikePrice;
    address public immutable override controller;

    constructor(
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice,
        address _controller
    ) {
        underlyingAsset = _underlyingAsset;
        strikeAsset = _strikeAsset;
        oracle = _oracle;
        expiryTime = _expiryTime;
        isCall = _isCall;
        strikePrice = _strikePrice;
        controller = _controller;
    }
}
