// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/// @dev Current pricing status of option. Only SETTLED options can be exercised
enum PriceStatus {
    ACTIVE,
    AWAITING_SETTLEMENT_PRICE,
    SETTLED
}

struct PriceWithDecimals {
    uint256 price;
    uint8 decimals;
}

/// @title For centrally managing a log of settlement prices, for each option.
/// @author Rolla
interface IPriceRegistry {
    event PriceStored(
        address indexed _oracle,
        address indexed _asset,
        uint88 indexed _expiryTime,
        uint8 _settlementPriceDecimals,
        uint256 _settlementPrice
    );

    event DisputePeriodSet(uint32 _disputePeriod);

    /// @notice Set the price at settlement for a particular asset, expiry
    /// @param _asset asset to set price for
    /// @param _expiryTime timestamp of price to set
    /// @param _settlementPriceDecimals number of decimals in settlement price
    /// @param _settlementPrice price at settlement
    function setSettlementPrice(
        address _asset,
        uint88 _expiryTime,
        uint8 _settlementPriceDecimals,
        uint256 _settlementPrice
    ) external;

    /// @notice Dispute a price at settlement for a particular asset, expiry and oracle
    /// @param _asset asset to set price for
    /// @param _expiryTime timestamp of price to set
    /// @param _oracle oracle to dispute price for
    /// @param _settlementPriceDecimals number of decimals in settlement price
    /// @param _settlementPrice the correct price at settlement
    function disputeSettlementPrice(
        address _oracle,
        address _asset,
        uint88 _expiryTime,
        uint8 _settlementPriceDecimals,
        uint256 _settlementPrice
    ) external;

    /// @notice Set the dispute period for the PriceRegistry
    /// @param disputePeriod_ the new dispute period
    function setDisputePeriod(uint32 disputePeriod_) external;

    /// @notice Fetch the settlement price with decimals from an oracle for an asset at a particular timestamp.
    /// @param _oracle oracle which price should come from
    /// @param _expiryTime timestamp we want the price for
    /// @param _asset asset to fetch price for
    /// @return the price (with decimals) which has been submitted for the asset at the timestamp by that oracle
    function getSettlementPriceWithDecimals(address _oracle, uint88 _expiryTime, address _asset)
        external
        view
        returns (PriceWithDecimals memory);

    /// @notice Fetch the settlement price from an oracle for an asset at a particular timestamp.
    /// @notice Rounds down if there's extra precision from the oracle
    /// @param _oracle oracle which price should come from
    /// @param _expiryTime timestamp we want the price for
    /// @param _asset asset to fetch price for
    /// @return the price which has been submitted for the asset at the timestamp by that oracle
    function getSettlementPrice(address _oracle, uint88 _expiryTime, address _asset) external view returns (uint256);

    /// @notice Get the price status of the option.
    /// @return the price status of the option. option is either active, awaiting settlement price or settled
    function getOptionPriceStatus(address _oracle, uint88 _expiryTime, address _asset)
        external
        view
        returns (PriceStatus);

    /// @notice Check if the settlement price for an asset exists from an oracle at a particular timestamp
    /// @param _oracle oracle from which price comes from
    /// @param _expiryTime timestamp of price
    /// @param _asset asset to check price for
    /// @return whether or not a price has been submitted for the asset at the timestamp by that oracle
    function hasSettlementPrice(address _oracle, uint88 _expiryTime, address _asset) external view returns (bool);

    // @notice The address of the OracleRegistry contract
    function oracleRegistry() external view returns (address);
}
