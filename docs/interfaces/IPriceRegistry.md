## `IPriceRegistry`

### `setSettlementPrice(address _asset, uint256 _expiryTimestamp, uint256 _settlementPrice)` (external)

Set the price at settlement for a particular asset, expiry

### `config() → contract IQuantConfig` (external)

quant central configuration

### `getSettlementPrice(address _oracle, address _asset, uint256 _expiryTimestamp) → uint256` (external)

Fetch the settlement price from an oracle for an asset at a particular timestamp.

### `hasSettlementPrice(address _oracle, address _asset, uint256 _expiryTimestamp) → bool` (external)

Check if the settlement price for an asset exists from an oracle at a particular timestamp
