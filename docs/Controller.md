## `Controller`

### `validQToken(address _qToken)`

### `constructor(address _optionsFactory)` (public)

### `mintOptionsPosition(address _to, address _qToken, uint256 _optionsAmount)` (external)

### `mintSpread(address _qTokenToMint, address _qTokenForCollateral, uint256 _optionsAmount)` (external)

### `exercise(address _qToken, uint256 _amount)` (external)

### `claimCollateral(uint256 _collateralTokenId, uint256 _amount)` (external)

### `neutralizePosition(uint256 _collateralTokenId, uint256 _amount)` (external)

### `getCollateralRequirement(address _qTokenToMint, address _qTokenForCollateral, uint256 _optionsAmount) → address collateral, uint256 collateralAmount` (public)

### `getPayout(address _qToken, uint256 _amount) → bool isSettled, address payoutToken, uint256 payoutAmount` (public)

### `_absSub(uint256 a, uint256 b) → uint256` (internal)
