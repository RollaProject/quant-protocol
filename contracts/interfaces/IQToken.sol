// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Current pricing status of option. Only SETTLED options can be exercised
enum PriceStatus {ACTIVE, AWAITING_SETTLEMENT_PRICE, SETTLED}

interface IQToken is IERC20 {
    function mint(address account, uint256 amount) external;

    function burn(address account, uint256 amount) external;

    function getOptionPriceStatus() external view returns (PriceStatus);
}
