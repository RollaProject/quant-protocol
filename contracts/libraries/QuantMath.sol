// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "./SignedConverter.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

/**
 * @title QuantMath
 * @notice FixedPoint library
 */
library QuantMath {
    using SignedSafeMath for int256;
    using SignedConverter for int256;
    using SafeMath for uint256;
    using SignedConverter for uint256;

    struct FixedPointInt {
        int256 value;
    }

    int256 private constant _SCALING_FACTOR = 1e27;
    uint256 private constant _BASE_DECIMALS = 27;

    /**
     * @notice constructs an `FixedPointInt` from an unscaled int, e.g., `b=5` gets stored internally as `5**27`.
     * @param a int to convert into a FixedPoint.
     * @return the converted FixedPoint.
     */
    function fromUnscaledInt(int256 a)
        internal
        pure
        returns (FixedPointInt memory)
    {
        return FixedPointInt(a.mul(_SCALING_FACTOR));
    }

    /**
     * @notice constructs an FixedPointInt from an scaled uint with {_decimals} decimals
     * Examples:
     * (1)  USDC    decimals = 6
     *      Input:  5 * 1e6 USDC  =>    Output: 5 * 1e27 (FixedPoint 8.0 USDC)
     * (2)  cUSDC   decimals = 8
     *      Input:  5 * 1e6 cUSDC =>    Output: 5 * 1e25 (FixedPoint 0.08 cUSDC)
     * @param _a uint256 to convert into a FixedPoint.
     * @param _decimals  original decimals _a has
     * @return the converted FixedPoint, with 27 decimals.
     */
    function fromScaledUint(uint256 _a, uint256 _decimals)
        internal
        pure
        returns (FixedPointInt memory)
    {
        FixedPointInt memory fixedPoint;

        if (_decimals == _BASE_DECIMALS) {
            fixedPoint = FixedPointInt(_a.uintToInt());
        } else if (_decimals > _BASE_DECIMALS) {
            uint256 exp = _decimals.sub(_BASE_DECIMALS);
            fixedPoint = FixedPointInt((_a.div(10**exp)).uintToInt());
        } else {
            uint256 exp = _BASE_DECIMALS - _decimals;
            fixedPoint = FixedPointInt((_a.mul(10**exp)).uintToInt());
        }

        return fixedPoint;
    }

    /**
     * @notice convert a FixedPointInt number to an uint256 with a specific number of decimals
     * @param _a FixedPointInt to convert
     * @param _decimals number of decimals that the uint256 should be scaled to
     * @param _roundDown True to round down the result, False to round up
     * @return the converted uint256
     */
    function toScaledUint(
        FixedPointInt memory _a,
        uint256 _decimals,
        bool _roundDown
    ) internal pure returns (uint256) {
        uint256 scaledUint;

        if (_decimals == _BASE_DECIMALS) {
            scaledUint = _a.value.intToUint();
        } else if (_decimals > _BASE_DECIMALS) {
            uint256 exp = _decimals - _BASE_DECIMALS;
            scaledUint = (_a.value).intToUint().mul(10**exp);
        } else {
            uint256 exp = _BASE_DECIMALS - _decimals;
            uint256 tailing;
            if (!_roundDown) {
                uint256 remainer = (_a.value).intToUint().mod(10**exp);
                if (remainer > 0) tailing = 1;
            }
            scaledUint = (_a.value).intToUint().div(10**exp).add(tailing);
        }

        return scaledUint;
    }

    /**
     * @notice add two signed integers, a + b
     * @param a FixedPointInt
     * @param b FixedPointInt
     * @return sum of the two signed integers
     */
    function add(FixedPointInt memory a, FixedPointInt memory b)
        internal
        pure
        returns (FixedPointInt memory)
    {
        return FixedPointInt(a.value.add(b.value));
    }

    /**
     * @notice subtract two signed integers, a-b
     * @param a FixedPointInt
     * @param b FixedPointInt
     * @return difference of two signed integers
     */
    function sub(FixedPointInt memory a, FixedPointInt memory b)
        internal
        pure
        returns (FixedPointInt memory)
    {
        return FixedPointInt(a.value.sub(b.value));
    }

    /**
     * @notice multiply two signed integers, a by b
     * @param a FixedPointInt
     * @param b FixedPointInt
     * @return mul of two signed integers
     */
    function mul(FixedPointInt memory a, FixedPointInt memory b)
        internal
        pure
        returns (FixedPointInt memory)
    {
        return FixedPointInt((a.value.mul(b.value)) / _SCALING_FACTOR);
    }

    /**
     * @notice divide two signed integers, a by b
     * @param a FixedPointInt
     * @param b FixedPointInt
     * @return div of two signed integers
     */
    function div(FixedPointInt memory a, FixedPointInt memory b)
        internal
        pure
        returns (FixedPointInt memory)
    {
        return FixedPointInt((a.value.mul(_SCALING_FACTOR)) / b.value);
    }

    /**
     * @notice minimum between two signed integers, a and b
     * @param a FixedPointInt
     * @param b FixedPointInt
     * @return min of two signed integers
     */
    function min(FixedPointInt memory a, FixedPointInt memory b)
        internal
        pure
        returns (FixedPointInt memory)
    {
        return a.value < b.value ? a : b;
    }

    /**
     * @notice maximum between two signed integers, a and b
     * @param a FixedPointInt
     * @param b FixedPointInt
     * @return max of two signed integers
     */
    function max(FixedPointInt memory a, FixedPointInt memory b)
        internal
        pure
        returns (FixedPointInt memory)
    {
        return a.value > b.value ? a : b;
    }

    /**
     * @notice is a is equal to b
     * @param a FixedPointInt
     * @param b FixedPointInt
     * @return True if equal, False if not
     */
    function isEqual(FixedPointInt memory a, FixedPointInt memory b)
        internal
        pure
        returns (bool)
    {
        return a.value == b.value;
    }

    /**
     * @notice is a greater than b
     * @param a FixedPointInt
     * @param b FixedPointInt
     * @return True if a > b, False if not
     */
    function isGreaterThan(FixedPointInt memory a, FixedPointInt memory b)
        internal
        pure
        returns (bool)
    {
        return a.value > b.value;
    }

    /**
     * @notice is a greater than or equal to b
     * @param a FixedPointInt
     * @param b FixedPointInt
     * @return True if a >= b, False if not
     */
    function isGreaterThanOrEqual(
        FixedPointInt memory a,
        FixedPointInt memory b
    ) internal pure returns (bool) {
        return a.value >= b.value;
    }

    /**
     * @notice is a is less than b
     * @param a FixedPointInt
     * @param b FixedPointInt
     * @return True if a < b, False if not
     */
    function isLessThan(FixedPointInt memory a, FixedPointInt memory b)
        internal
        pure
        returns (bool)
    {
        return a.value < b.value;
    }

    /**
     * @notice is a less than or equal to b
     * @param a FixedPointInt
     * @param b FixedPointInt
     * @return True if a <= b, False if not
     */
    function isLessThanOrEqual(FixedPointInt memory a, FixedPointInt memory b)
        internal
        pure
        returns (bool)
    {
        return a.value <= b.value;
    }
}
