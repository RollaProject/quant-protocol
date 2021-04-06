## `OracleRegistry`

oracle provider registry for holding a list of oracle providers and their id




### `constructor(address _config)` (public)





### `addOracle(address _oracle) → uint256` (external)

Add an oracle to the oracle registry which will generate an id. By default oracles are deactivated




### `isOracleRegistered(address _oracle) → bool` (external)

Check if an oracle is registered in the registry




### `isOracleActive(address _oracle) → bool` (external)

Check if an oracle is active i.e. are we allowed to create options with this oracle




### `getOracleId(address _oracle) → uint256` (external)

Get the numeric id of an oracle




### `deactivateOracle(address _oracle) → bool` (external)

Deactivate an oracle so no new options can be created with this oracle address.




### `activateOracle(address _oracle) → bool` (external)

Activate an oracle so options can be created with this oracle address.




### `getOraclesLength() → uint256` (external)

Get total number of oracles in registry





### `AddedOracle(address oracle, uint256 oracleId)`





### `ActivatedOracle(address oracle)`





### `DeactivatedOracle(address oracle)`





