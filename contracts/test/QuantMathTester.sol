// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma abicoder v2;

import "../libraries/QuantMath.sol";

contract QuantMathTester {
    using QuantMath for QuantMath.FixedPointInt;

    function testFromUnscaledInt(int256 a)
        external
        pure
        returns (QuantMath.FixedPointInt memory)
    {
        return QuantMath.fromUnscaledInt(a);
    }

    function testAdd(
        QuantMath.FixedPointInt memory a,
        QuantMath.FixedPointInt memory b
    ) external pure returns (QuantMath.FixedPointInt memory) {
        return a.add(b);
    }

    function testSub(
        QuantMath.FixedPointInt memory a,
        QuantMath.FixedPointInt memory b
    ) external pure returns (QuantMath.FixedPointInt memory) {
        return a.sub(b);
    }

    function testMul(
        QuantMath.FixedPointInt memory a,
        QuantMath.FixedPointInt memory b
    ) external pure returns (QuantMath.FixedPointInt memory) {
        return a.mul(b);
    }

    function testDiv(
        QuantMath.FixedPointInt memory a,
        QuantMath.FixedPointInt memory b
    ) external pure returns (QuantMath.FixedPointInt memory) {
        return a.div(b);
    }

    function testMin(
        QuantMath.FixedPointInt memory a,
        QuantMath.FixedPointInt memory b
    ) external pure returns (QuantMath.FixedPointInt memory) {
        return QuantMath.min(a, b);
    }

    function testMax(
        QuantMath.FixedPointInt memory a,
        QuantMath.FixedPointInt memory b
    ) external pure returns (QuantMath.FixedPointInt memory) {
        return QuantMath.max(a, b);
    }

    function testIsEqual(
        QuantMath.FixedPointInt memory a,
        QuantMath.FixedPointInt memory b
    ) external pure returns (bool) {
        return a.isEqual(b);
    }

    function testIsGreaterThan(
        QuantMath.FixedPointInt memory a,
        QuantMath.FixedPointInt memory b
    ) external pure returns (bool) {
        return a.isGreaterThan(b);
    }

    function testIsGreaterThanOrEqual(
        QuantMath.FixedPointInt memory a,
        QuantMath.FixedPointInt memory b
    ) external pure returns (bool) {
        return a.isGreaterThanOrEqual(b);
    }

    function testIsLessThan(
        QuantMath.FixedPointInt memory a,
        QuantMath.FixedPointInt memory b
    ) external pure returns (bool) {
        return a.isLessThan(b);
    }

    function testIsLessThanOrEqual(
        QuantMath.FixedPointInt memory a,
        QuantMath.FixedPointInt memory b
    ) external pure returns (bool) {
        return a.isLessThanOrEqual(b);
    }
}
