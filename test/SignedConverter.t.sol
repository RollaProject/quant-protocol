// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import {SignedConverter} from "../src/libraries/SignedConverter.sol";

contract SignedConverterTest is Test {
    function testCannotConvertNegativeIntToUint(int16 n) public {
        vm.assume(n < 0);
        vm.expectRevert(bytes("QuantMath: negative int"));
        SignedConverter.intToUint(n);
    }
}
