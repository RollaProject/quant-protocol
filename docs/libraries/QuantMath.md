## `QuantMath`

FixedPoint library

### `fromUnscaledInt(int256 a) → struct QuantMath.FixedPointInt` (internal)

constructs an `FixedPointInt` from an unscaled int, e.g., `b=5` gets stored internally as `5**27`.

### `fromScaledUint(uint256 _a, uint256 _decimals) → struct QuantMath.FixedPointInt` (internal)

constructs an FixedPointInt from an scaled uint with {\_decimals} decimals
Examples:
(1) USDC decimals = 6
Input: 5 _ 1e6 USDC => Output: 5 _ 1e27 (FixedPoint 8.0 USDC)
(2) cUSDC decimals = 8
Input: 5 _ 1e6 cUSDC => Output: 5 _ 1e25 (FixedPoint 0.08 cUSDC)

### `toScaledUint(struct QuantMath.FixedPointInt _a, uint256 _decimals, bool _roundDown) → uint256` (internal)

convert a FixedPointInt number to an uint256 with a specific number of decimals

### `add(struct QuantMath.FixedPointInt a, struct QuantMath.FixedPointInt b) → struct QuantMath.FixedPointInt` (internal)

add two signed integers, a + b

### `sub(struct QuantMath.FixedPointInt a, struct QuantMath.FixedPointInt b) → struct QuantMath.FixedPointInt` (internal)

subtract two signed integers, a-b

### `mul(struct QuantMath.FixedPointInt a, struct QuantMath.FixedPointInt b) → struct QuantMath.FixedPointInt` (internal)

multiply two signed integers, a by b

### `div(struct QuantMath.FixedPointInt a, struct QuantMath.FixedPointInt b) → struct QuantMath.FixedPointInt` (internal)

divide two signed integers, a by b

### `min(struct QuantMath.FixedPointInt a, struct QuantMath.FixedPointInt b) → struct QuantMath.FixedPointInt` (internal)

minimum between two signed integers, a and b

### `max(struct QuantMath.FixedPointInt a, struct QuantMath.FixedPointInt b) → struct QuantMath.FixedPointInt` (internal)

maximum between two signed integers, a and b

### `isEqual(struct QuantMath.FixedPointInt a, struct QuantMath.FixedPointInt b) → bool` (internal)

is a is equal to b

### `isGreaterThan(struct QuantMath.FixedPointInt a, struct QuantMath.FixedPointInt b) → bool` (internal)

is a greater than b

### `isGreaterThanOrEqual(struct QuantMath.FixedPointInt a, struct QuantMath.FixedPointInt b) → bool` (internal)

is a greater than or equal to b

### `isLessThan(struct QuantMath.FixedPointInt a, struct QuantMath.FixedPointInt b) → bool` (internal)

is a is less than b

### `isLessThanOrEqual(struct QuantMath.FixedPointInt a, struct QuantMath.FixedPointInt b) → bool` (internal)

is a less than or equal to b
