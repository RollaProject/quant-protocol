// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../libraries/SignedConverter.sol";

contract SignedConverterTester {
    using SignedConverter for int256;
    using SignedConverter for uint256;

    function fromIntTest(int256 a) external pure returns (uint256) {
        return SignedConverter.intToUint(a);
    }

    function fromUintTest(uint256 a) external pure returns (int256) {
        return SignedConverter.uintToInt(a);
    }
}
