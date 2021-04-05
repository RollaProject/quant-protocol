## `OracleProviderRegistry`

oracle provider registry for holding a list of oracle providers and their id

### `constructor(address _config)` (public)

### `addOracle(address _oracle) → uint256` (external)

Add an asset to the oracle registry which will generate an id

Once this is set for an asset, it can't be changed or removed

### `getOraclesLength() → uint256` (external)

Get total number of oracles in registry
