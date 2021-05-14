// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../interfaces/IQuantConfig.sol";
import "../interfaces/IPriceRegistry.sol";

/// @title For centrally managing a log of settlement prices, for each option.
contract PriceRegistry is IPriceRegistry {
    /// @inheritdoc IPriceRegistry
    IQuantConfig public override config;

    /// @dev oracle => asset => expiry => price
    mapping(address => mapping(address => mapping(uint256 => uint256)))
        private _settlementPrices;

    /// @param _config address of quant central configuration
    constructor(address _config) {
        config = IQuantConfig(_config);
    }

    /// @inheritdoc IPriceRegistry
    function setSettlementPrice(
        address _asset,
        uint256 _expiryTimestamp,
        uint256 _settlementPrice
    ) external override {
        require(
            config.hasRole(
                config.quantRoles("PRICE_SUBMITTER_ROLE"),
                msg.sender
            ),
            "PriceRegistry: Price submitter is not an oracle"
        );

        uint256 currentSettlementPrice =
            _settlementPrices[msg.sender][_asset][_expiryTimestamp];

        require(
            currentSettlementPrice == 0,
            "PriceRegistry: Settlement price has already been set"
        );

        require(
            _expiryTimestamp <= block.timestamp,
            "PriceRegistry: Can't set a price for a time in the future"
        );

        _settlementPrices[msg.sender][_asset][
            _expiryTimestamp
        ] = _settlementPrice;
    }

    /// @inheritdoc IPriceRegistry
    function getSettlementPrice(
        address _oracle,
        address _asset,
        uint256 _expiryTimestamp
    ) external view override returns (uint256) {
        uint256 settlementPrice =
            _settlementPrices[_oracle][_asset][_expiryTimestamp];
        require(
            settlementPrice != 0,
            "PriceRegistry: No settlement price has been set"
        );

        return settlementPrice;
    }

    /// @inheritdoc IPriceRegistry
    function hasSettlementPrice(
        address _oracle,
        address _asset,
        uint256 _expiryTimestamp
    ) public view override returns (bool) {
        return _settlementPrices[_oracle][_asset][_expiryTimestamp] != 0;
    }
}
