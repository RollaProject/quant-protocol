// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WETH is ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH") {
        _setupDecimals(18);
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
