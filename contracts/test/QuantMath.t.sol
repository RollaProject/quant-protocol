// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import {QuantMath} from "../libraries/QuantMath.sol";

contract QuantMathTest is Test {
    function testMultiplicationOverflow() public {
        int256 a = 2e13;
        int256 b = 3e13;

        vm.expectRevert(stdError.arithmeticError);
        QuantMath.mul(
            QuantMath.fromUnscaledInt(a), QuantMath.fromUnscaledInt(b), true
        );
    }
}