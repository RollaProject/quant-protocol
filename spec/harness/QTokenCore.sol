// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

import "../../contracts/options/QToken.sol";

contract QTokenCore is QToken {
    address public override underlyingAsset;
    address public override strikeAsset;
    address public override oracle;
    uint88 public override expiryTime;
    bool public override isCall;
    uint256 public override strikePrice;
    address public override controller;

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
