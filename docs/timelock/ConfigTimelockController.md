## `ConfigTimelockController`

### `constructor(uint256 _minDelay, address[] _proposers, address[] _executors)` (public)

### `setDelay(bytes32 _protocolValue, uint256 _newDelay)` (external)

### `schedule(address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt, uint256 delay)` (public)

### `scheduleSetProtocolAddress(bytes32 protocolAddress, address newAddress, address quantConfig, uint256 eta)` (public)

### `scheduleSetProtocolUint256(bytes32 protocolUint256, uint256 newUint256, address quantConfig, uint256 eta)` (public)

### `scheduleSetProtocolBoolean(bytes32 protocolBoolean, bool newBoolean, address quantConfig, uint256 eta)` (public)

### `scheduleSetProtocolRole(string protocolRole, address roleAdmin, address quantConfig, uint256 eta)` (public)

### `scheduleBatch(address[] targets, uint256[] values, bytes[] datas, bytes32 predecessor, bytes32 salt, uint256 delay)` (public)

### `scheduleBatchSetProtocolAddress(bytes32[] protocolValues, address[] newAddresses, address quantConfig, uint256 eta)` (public)

### `scheduleBatchSetProtocolUints(bytes32[] protocolValues, uint256[] newUints, address quantConfig, uint256 eta)` (public)

### `scheduleBatchSetProtocolBooleans(bytes32[] protocolValues, bool[] newBooleans, address quantConfig, uint256 eta)` (public)

### `scheduleBatchSetProtocolRoles(string[] protocolRoles, address[] roleAdmins, address quantConfig, uint256 eta)` (public)

### `executeSetProtocolAddress(bytes32 protocolAddress, address newAddress, address quantConfig, uint256 eta)` (public)

### `executeSetProtocolUint256(bytes32 protocolUint256, uint256 newUint256, address quantConfig, uint256 eta)` (public)

### `executeSetProtocolBoolean(bytes32 protocolBoolean, bool newBoolean, address quantConfig, uint256 eta)` (public)

### `executeSetProtocolRole(string protocolRole, address roleAdmin, address quantConfig, uint256 eta)` (public)

### `executeBatchSetProtocolAddress(bytes32[] protocolValues, address[] newAddresses, address quantConfig, uint256 eta)` (public)

### `executeBatchSetProtocolUint256(bytes32[] protocolValues, uint256[] newUints, address quantConfig, uint256 eta)` (public)

### `executeBatchSetProtocolBoolean(bytes32[] protocolValues, bool[] newBooleans, address quantConfig, uint256 eta)` (public)

### `executeBatchSetProtocolRoles(string[] protocolRoles, address[] roleAdmins, address quantConfig, uint256 eta)` (public)

### `_getProtocolValueDelay(bytes32 protocolValue) → uint256` (internal)

### `_isProtocoValueSetter(bytes data) → bool` (internal)

### `_encodeSetProtocolAddress(bytes32 _protocolAddress, address _newAddress, address _quantConfig) → bytes` (internal)

### `_encodeSetProtocolUint256(bytes32 _protocolUint256, uint256 _newUint256, address _quantConfig) → bytes` (internal)

### `_encodeSetProtocolBoolean(bytes32 _protocolBoolean, bool _newBoolean, address _quantConfig) → bytes` (internal)

### `_encodeSetProtocolRole(string _protocolRole, address _roleAdmin, address _quantConfig) → bytes` (internal)
