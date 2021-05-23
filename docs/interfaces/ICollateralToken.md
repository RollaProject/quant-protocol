## `ICollateralToken`

Can be used by owners to claim their collateral

### `createCollateralToken(address _qTokenAddress, address _qTokenAsCollateral) → uint256 id` (external)

Create new CollateralTokens

### `mintCollateralToken(address recipient, uint256 collateralTokenId, uint256 amount)` (external)

Mint CollateralTokens for a given account

### `burnCollateralToken(address owner, uint256 collateralTokenId, uint256 amount)` (external)

Mint CollateralTokens for a given account

### `mintCollateralTokenBatch(address recipient, uint256[] ids, uint256[] amounts)` (external)

Batched minting of multiple CollateralTokens for a given account

Should be used when minting multiple CollateralTokens for a single user,
i.e., when a user buys more than one short position through the interface
ids and amounts must have the same length

### `burnCollateralTokenBatch(address owner, uint256[] ids, uint256[] amounts)` (external)

Batched burning of of multiple CollateralTokens from a given account

Should be used when burning multiple CollateralTokens for a single user,
i.e., when a user sells more than one short position through the interface
ids and amounts shoud have the same length

### `quantConfig() → contract IQuantConfig` (external)

The Quant system config

### `idToInfo(uint256) → address, address` (external)

mapping of CollateralToken ids to their respective info struct

### `collateralTokenIds(uint256) → uint256` (external)

array of all the created CollateralToken ids

### `tokenSupplies(uint256) → uint256` (external)

mapping from token ids to their supplies

### `getCollateralTokenId(address _qToken, address _qTokenAsCollateral) → uint256 id` (external)

Returns a unique CollateralToken id based on its parameters

### `CollateralTokenCreated(address qTokenAddress, address qTokenAsCollateral, uint256 id, uint256 allCollateralTokensLength)`

event emitted when a new CollateralToken is created

### `CollateralTokenMinted(address recipient, uint256 id, uint256 amount)`

event emitted when CollateralTokens are minted

### `CollateralTokenBurned(address owner, uint256 id, uint256 amount)`

event emitted when CollateralTokens are burned
