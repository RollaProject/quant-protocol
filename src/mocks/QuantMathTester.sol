// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../libraries/QuantMath.sol";

contract QuantMathTester {
    using QuantMath for QuantMath.FixedPointInt;

    function fromUnscaledIntTest(int256 a) external pure returns (QuantMath.FixedPointInt memory) {
        return QuantMath.fromUnscaledInt(a);
    }

    function fromScaledUintTest(uint256 a, uint256 decimals) external pure returns (QuantMath.FixedPointInt memory) {
        return QuantMath.fromScaledUint(a, decimals);
    }

    function toScaledUintTest(QuantMath.FixedPointInt memory a, uint256 decimals, bool roundDown)
        external
        pure
        returns (uint256)
    {
        return QuantMath.toScaledUint(a, decimals, roundDown);
    }

    function addTest(QuantMath.FixedPointInt memory a, QuantMath.FixedPointInt memory b)
        external
        pure
        returns (QuantMath.FixedPointInt memory)
    {
        return a.add(b);
    }

    function subTest(QuantMath.FixedPointInt memory a, QuantMath.FixedPointInt memory b)
        external
        pure
        returns (QuantMath.FixedPointInt memory)
    {
        return a.sub(b);
    }

    function mulTest(QuantMath.FixedPointInt memory a, QuantMath.FixedPointInt memory b)
        external
        pure
        returns (QuantMath.FixedPointInt memory)
    {
        return a.mul(b, true);
    }

    function divTest(QuantMath.FixedPointInt memory a, QuantMath.FixedPointInt memory b)
        external
        pure
        returns (QuantMath.FixedPointInt memory)
    {
        return a.div(b, true);
    }

    function minTest(QuantMath.FixedPointInt memory a, QuantMath.FixedPointInt memory b)
        external
        pure
        returns (QuantMath.FixedPointInt memory)
    {
        return QuantMath.min(a, b);
    }

    function maxTest(QuantMath.FixedPointInt memory a, QuantMath.FixedPointInt memory b)
        external
        pure
        returns (QuantMath.FixedPointInt memory)
    {
        return QuantMath.max(a, b);
    }

    function isEqualTest(QuantMath.FixedPointInt memory a, QuantMath.FixedPointInt memory b)
        external
        pure
        returns (bool)
    {
        return a.isEqual(b);
    }

    function isGreaterThanTest(QuantMath.FixedPointInt memory a, QuantMath.FixedPointInt memory b)
        external
        pure
        returns (bool)
    {
        return a.isGreaterThan(b);
    }

    function isGreaterThanOrEqualTest(QuantMath.FixedPointInt memory a, QuantMath.FixedPointInt memory b)
        external
        pure
        returns (bool)
    {
        return a.isGreaterThanOrEqual(b);
    }

    function isLessThanTest(QuantMath.FixedPointInt memory a, QuantMath.FixedPointInt memory b)
        external
        pure
        returns (bool)
    {
        return a.isLessThan(b);
    }

    function isLessThanOrEqualTest(QuantMath.FixedPointInt memory a, QuantMath.FixedPointInt memory b)
        external
        pure
        returns (bool)
    {
        return a.isLessThanOrEqual(b);
    }
}
