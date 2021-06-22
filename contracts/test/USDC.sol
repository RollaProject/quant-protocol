// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "../../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _setupDecimals(6);
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
