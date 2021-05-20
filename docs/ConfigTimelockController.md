## `ConfigTimelockController`

### `constructor(uint256 _minDelay, address[] _proposers, address[] _executors)` (public)

### `setDelay(bytes32 _protocolValue, uint256 _newDelay)` (external)

### `schedule(address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt, uint256 delay)` (public)

### `scheduleSetProtocolAddress(bytes32 protocolAddress, address newAddress, address quantConfig)` (public)

### `scheduleSetProtocolUint256(bytes32 protocolUint256, uint256 newUint256, address quantConfig)` (public)

### `scheduleSetProtocolBoolean(bytes32 protocolBoolean, bool newBoolean, address quantConfig)` (public)

### `scheduleBatch(address[] targets, uint256[] values, bytes[] datas, bytes32 predecessor, bytes32 salt, uint256 delay)` (public)

### `scheduleBatchSetProtocolAddress(bytes32[] protocolValues, address[] newAddresses, address quantConfig)` (public)

### `scheduleBatchSetProtocolUints(bytes32[] protocolValues, uint256[] newUints, address quantConfig)` (public)

### `scheduleBatchSetProtocolBooleans(bytes32[] protocolValues, bool[] newBooleans, address quantConfig)` (public)

### `hashOperation(address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt) → bytes32 hash` (public)

### `hashOperationBatch(address[] targets, uint256[] values, bytes[] datas, bytes32 predecessor, bytes32 salt) → bytes32 hash` (public)

### `_isProtocoValueSetter(bytes data) → bool` (internal)

### `_getProtocolValueDelay(bytes32 protocolValue) → uint256` (internal)
