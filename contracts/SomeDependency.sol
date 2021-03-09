//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "hardhat/console.sol";

contract SomeDependency {
    function getValue() public view returns (uint256) {
        return 1;
    }
}