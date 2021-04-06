// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

/// @dev Current pricing status of option. Only SETTLED options can be exercised
enum PriceStatus {ACTIVE, AWAITING_SETTLEMENT_PRICE, SETTLED}

interface IQToken {
    function mint(address account, uint256 amount) external;

    function burn(address account, uint256 amount) external;

    function getOptionPriceStatus() external view returns (PriceStatus);
}
