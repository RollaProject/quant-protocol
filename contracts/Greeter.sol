//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "hardhat/console.sol";
import "./SomeDependency.sol";

contract Greeter {
    string greeting;
    address dependency;

    constructor(string memory _greeting, address _dependency) {
        console.log("Deploying a Greeter with greeting:", _greeting);
        greeting = _greeting;
        dependency = _dependency;
    }

    function greet() public view returns (string memory) {
        return greeting;
    }

    function setGreeting(string memory _greeting) public {
        console.log("Changing greeting from '%s' to '%s'", greeting, _greeting);
        greeting = _greeting;
    }

    function getValue() public view returns (uint256) {
        return SomeDependency(dependency).getValue();
    }
}