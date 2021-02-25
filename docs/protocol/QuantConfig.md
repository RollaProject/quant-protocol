## `QuantConfig`

For storing constants, variables and allowing them to be changed by the admin (governance)


This should be used as a central access control manager which other contracts use to check permissions


### `setFee(uint256 _fee)` (external)

Set the protocol fee


Only accounts or contracts with the admin role should call this function


### `setPriceRegistry(address _priceRegistry)` (external)





### `initialize(address _admin)` (public)

Initializes the system roles and assign them to the given admin address





