## `QuantConfigV2`

For storing constants, variables and allowing them to be changed by the admin (governance)

This should be used as a central access control manager which other contracts use to check permissions

### `setFee(uint256 _fee)` (external)

Set the protocol fee

Only accounts or contracts with the admin role should call this function

### `setPriceRegistry(address _priceRegistry)` (external)

Set the protocol's price registry

Can only be called once, and by accounts or contracts with the admin role

### `setAssetsRegistry(address _assetsRegistry)` (external)

Set the protocol assets registry

Only accounts or contracts with the admin role should call this contract

### `initialize(address _admin)` (public)

Initializes the system roles and assign them to the given admin address
