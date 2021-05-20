## `QuantConfigV2`

For storing constants, variables and allowing them to be changed by the admin (governance)

This should be used as a central access control manager which other contracts use to check permissions

### `setProtocolAddress(bytes32 _protocolAddress, address _newValue)` (external)

### `setProtocolUint256(bytes32 _protocolUint256, uint256 _newValue)` (external)

### `setProtocolBoolean(bytes32 _protocolBoolean, bool _newValue)` (external)

### `setProtocolRole(string _protocolRole, address _roleAdmin)` (external)

### `setRoleAdmin(bytes32 role, bytes32 adminRole)` (external)

### `initialize(address payable _timelockController)` (public)

Initializes the system roles and assign them to the given TimelockController address

The TimelockController should have a Quant multisig as its sole proposer
