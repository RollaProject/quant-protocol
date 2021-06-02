
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma abicoder v2;

import "../../contracts/options/QToken.sol";

contract QTokenA is QToken {

	constructor(
        address _quantConfig,
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    )  QToken(_quantConfig, _underlyingAsset, _strikeAsset, _oracle, _strikePrice, _expiryTime, _isCall) public {}

 }