// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

interface IPriceRegistry {
    function setSettlementPrice(
        address _asset,
        uint256 _expiryTimestamp,
        uint256 _settlementPrice
    ) external;

    function getSettlementPrice(
        address _oracle,
        address _asset,
        uint256 _expiryTimestamp
    ) external view returns (uint256);

    function hasSettlementPrice(
        address _oracle,
        address _asset,
        uint256 _expiryTimestamp
    ) external view returns (bool);
}
