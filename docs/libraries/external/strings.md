## `strings`

### `toSlice(string self) → struct strings.slice` (internal)

### `len(bytes32 self) → uint256` (internal)

### `toSliceB32(bytes32 self) → struct strings.slice ret` (internal)

### `copy(struct strings.slice self) → struct strings.slice` (internal)

### `toString(struct strings.slice self) → string` (internal)

### `len(struct strings.slice self) → uint256 l` (internal)

### `empty(struct strings.slice self) → bool` (internal)

### `compare(struct strings.slice self, struct strings.slice other) → int256` (internal)

### `equals(struct strings.slice self, struct strings.slice other) → bool` (internal)

### `nextRune(struct strings.slice self, struct strings.slice rune) → struct strings.slice` (internal)

### `nextRune(struct strings.slice self) → struct strings.slice ret` (internal)

### `ord(struct strings.slice self) → uint256 ret` (internal)

### `keccak(struct strings.slice self) → bytes32 ret` (internal)

### `startsWith(struct strings.slice self, struct strings.slice needle) → bool` (internal)

### `beyond(struct strings.slice self, struct strings.slice needle) → struct strings.slice` (internal)

### `endsWith(struct strings.slice self, struct strings.slice needle) → bool` (internal)

### `until(struct strings.slice self, struct strings.slice needle) → struct strings.slice` (internal)

### `find(struct strings.slice self, struct strings.slice needle) → struct strings.slice` (internal)

### `rfind(struct strings.slice self, struct strings.slice needle) → struct strings.slice` (internal)

### `split(struct strings.slice self, struct strings.slice needle, struct strings.slice token) → struct strings.slice` (internal)

### `split(struct strings.slice self, struct strings.slice needle) → struct strings.slice token` (internal)

### `rsplit(struct strings.slice self, struct strings.slice needle, struct strings.slice token) → struct strings.slice` (internal)

### `rsplit(struct strings.slice self, struct strings.slice needle) → struct strings.slice token` (internal)

### `count(struct strings.slice self, struct strings.slice needle) → uint256 cnt` (internal)

### `contains(struct strings.slice self, struct strings.slice needle) → bool` (internal)

### `concat(struct strings.slice self, struct strings.slice other) → string` (internal)

### `join(struct strings.slice self, struct strings.slice[] parts) → string` (internal)
