// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "../../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20(name_, symbol_) {
        _setupDecimals(decimals_);
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
