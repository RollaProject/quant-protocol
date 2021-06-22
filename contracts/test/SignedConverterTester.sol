// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma abicoder v2;

import "../libraries/SignedConverter.sol";

contract SignedConverterTester {
    using SignedConverter for int256;
    using SignedConverter for uint256;

    function testFromInt(int256 a) external pure returns (uint256) {
        return SignedConverter.intToUint(a);
    }

    function testFromUint(uint256 a) external pure returns (int256) {
        return SignedConverter.uintToInt(a);
    }
}
