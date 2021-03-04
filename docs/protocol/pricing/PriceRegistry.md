## `PriceRegistry`

### `constructor(address _config)` (public)

### `setSettlementPrice(address _asset, uint256 _settlementPrice, uint256 _expiryTimestamp)` (external)

Set the price at settlement for a particular asset, expiry

### `getSettlementPrice(address _oracle, address _asset, uint256 _expiryTimestamp) → uint256` (external)

Fetch the settlement price from an oracle for an asset at a particular timestamp.

### `getOptionPriceStatus(address _qToken) → enum PriceRegistry.PriceStatus` (external)

Get the price status of the option.

### `hasSettlementPrice(address _oracle, address _asset, uint256 _expiryTimestamp) → bool` (public)

Check if the settlement price for an asset exists from an oracle at a particular timestamp
