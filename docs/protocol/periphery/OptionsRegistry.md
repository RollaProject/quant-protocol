## `OptionsRegistry`

An options registry which anyone can deploy a version of. This is independent from the Quant protocol.

### `constructor(address _admin)` (public)

### `addOption(address _qToken)` (external)

### `makeOptionVisible(address _qToken, uint256 index)` (external)

### `makeOptionInvisible(address _qToken, uint256 index)` (external)

### `getOptionDetails(address _underlyingAsset, uint256 _index) → struct OptionsRegistry.OptionDetails` (external)

### `numberOfUnderlyingAssets() → uint256` (external)

### `numberOfOptionsForUnderlying(address _underlying) → uint256` (external)

### `NewOption(address underlyingAsset, address qToken, uint256 index)`

### `OptionVisibilityChanged(address underlyingAsset, address qToken, uint256 index, bool isVisible)`
