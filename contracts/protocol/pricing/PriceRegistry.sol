// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../QuantConfig.sol";
import "./OracleRegistry.sol";

/// @title For centrally managing a log of settlement prices, for each option.
contract PriceRegistry {
    /// @notice quant central configuration
    QuantConfig public config;

    /// @dev oracle => asset => expiry => price
    mapping(address => mapping(address => mapping(uint256 => uint256)))
        private _settlementPrices;

    /// @param _config address of quant central configuration
    constructor(address _config) {
        config = QuantConfig(_config);
    }

    /// @notice Set the price at settlement for a particular asset, expiry
    /// @param _asset asset to set price for
    /// @param _settlementPrice price at settlement
    /// @param _expiryTimestamp timestamp of price to set
    function setSettlementPrice(
        address _asset,
        uint256 _expiryTimestamp,
        uint256 _settlementPrice
    ) external {
        require(
            config.hasRole(config.PRICE_SUBMITTER_ROLE(), msg.sender),
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

    /// @notice Fetch the settlement price from an oracle for an asset at a particular timestamp.
    /// @param _oracle oracle which price should come from
    /// @param _asset asset to fetch price for
    /// @param _expiryTimestamp timestamp we want the price for
    /// @return the price which has been submitted for the asset at the timestamp by that oracle
    function getSettlementPrice(
        address _oracle,
        address _asset,
        uint256 _expiryTimestamp
    ) external view returns (uint256) {
        uint256 settlementPrice =
            _settlementPrices[_oracle][_asset][_expiryTimestamp];
        require(
            settlementPrice != 0,
            "PriceRegistry: No settlement price has been set"
        );

        return settlementPrice;
    }

    /// @notice Check if the settlement price for an asset exists from an oracle at a particular timestamp
    /// @param _oracle oracle from which price comes from
    /// @param _asset asset to check price for
    /// @param _expiryTimestamp timestamp of price
    /// @return whether or not a price has been submitted for the asset at the timestamp by that oracle
    function hasSettlementPrice(
        address _oracle,
        address _asset,
        uint256 _expiryTimestamp
    ) public view returns (bool) {
        return _settlementPrices[_oracle][_asset][_expiryTimestamp] != 0;
    }
}
