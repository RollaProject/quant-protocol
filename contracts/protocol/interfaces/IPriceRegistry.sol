// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "./IQuantConfig.sol";

/// @title For centrally managing a log of settlement prices, for each option.
interface IPriceRegistry {
    /// @notice Set the price at settlement for a particular asset, expiry
    /// @param _asset asset to set price for
    /// @param _settlementPrice price at settlement
    /// @param _expiryTimestamp timestamp of price to set
    function setSettlementPrice(
        address _asset,
        uint256 _expiryTimestamp,
        uint256 _settlementPrice
    ) external;

    /// @notice quant central configuration
    function config() external view returns (IQuantConfig);

    /// @notice Fetch the settlement price from an oracle for an asset at a particular timestamp.
    /// @param _oracle oracle which price should come from
    /// @param _asset asset to fetch price for
    /// @param _expiryTimestamp timestamp we want the price for
    /// @return the price which has been submitted for the asset at the timestamp by that oracle
    function getSettlementPrice(
        address _oracle,
        address _asset,
        uint256 _expiryTimestamp
    ) external view returns (uint256);

    /// @notice Check if the settlement price for an asset exists from an oracle at a particular timestamp
    /// @param _oracle oracle from which price comes from
    /// @param _asset asset to check price for
    /// @param _expiryTimestamp timestamp of price
    /// @return whether or not a price has been submitted for the asset at the timestamp by that oracle
    function hasSettlementPrice(
        address _oracle,
        address _asset,
        uint256 _expiryTimestamp
    ) external view returns (bool);
}
