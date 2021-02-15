// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../QuantConfig.sol";

/// @title For centrally managing a log of settlement prices, for each option.
contract PriceRegistry {
    /// @notice quant central configuration
    QuantConfig public config;

    /// @dev oracle => asset => expiry => price
    mapping(address => mapping(address => mapping(uint256 => uint256))) settlementPrices;

    enum PRICE_STATUS {
        ACTIVE, AWAITING_SETTLEMENT_PRICE, SETTLED
    }

    /// @param _config address of quant central configuration
    constructor(
        address _config
    ) {
        config = QuantConfig(_config);
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
        return settlementPrices[_oracle][_asset][_expiryTimestamp] != 0;
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
        uint256 settlementPrice = settlementPrices[_oracle][_asset][_expiryTimestamp];
        require(settlementPrice != 0, "PriceRegistry: No settlement price has been set");

        return settlementPrice;
    }

    /// @notice Fetch the settlement price from an oracle for an asset at a particular timestamp.
    /// @param _oracle oracle which price should come from
    /// @param _asset asset to fetch price for
    /// @param _expiryTimestamp timestamp we want the price for
    /// @return the price which has been submitted for the asset at the timestamp by that oracle
    function setSettlementPrice(
        address _asset,
        uint256 _settlementPrice,
        uint256 _expiryTimestamp
    ) external {
        require(
            config.hasRole(config.PRICE_SUBMITTER_ROLE(), msg.sender),
            "PriceRegistry: Price submitter is not an oracle"
        );

        uint256 currentSettlementPrice = settlementPrices[msg.sender][_asset][_expiryTimestamp];

        require(currentSettlementPrice == 0, "PriceRegistry: Settlement price has already been set");

        settlementPrices[msg.sender][_asset][_expiryTimestamp] = _settlementPrice;
    }

    /// @notice Get the price status of the option.
    /// @param _qToken option we want the status for
    /// @return the price status of the option. option is either active, awaiting settlement price or settled
    //todo should this live in the option itself?
    function getOptionPriceStatus(
        address _qToken
    ) external view returns(PRICE_STATUS) {
        address oracle = address(0);
        address asset = address(0);
        uint256 expiryTimestamp = 123;

        if(block.timestamp > expiryTimestamp) {
            if(hasSettlementPrice(oracle, asset, expiryTimestamp)) {
                return PRICE_STATUS.SETTLED;
            }
            return PRICE_STATUS.AWAITING_SETTLEMENT_PRICE;
        } else {
            return PRICE_STATUS.ACTIVE;
        }
    }
}