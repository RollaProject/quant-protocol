## `Controller`

### `validQToken(address _qToken)`

### `constructor(address _optionsFactory)` (public)

### `mintOptionsPosition(address _qToken, uint256 _optionsAmount)` (external)

### `mintSpread(address _qTokenToMint, address _qTokenForCollateral, uint256 _optionsAmount)` (external)

### `exercise(address _qToken, uint256 _amount)` (external)

### `claimCollateral(uint256 _collateralTokenId, uint256 _amount)` (external)

### `neutralizePosition(uint256 _collateralTokenId, uint256 _amount)` (external)

### `getCollateralRequirement(address _qTokenToMint, address _qTokenForCollateral, uint256 _optionsAmount) → address collateral, uint256 collateralAmount` (public)

### `_absSub(uint256 a, uint256 b) → uint256` (internal)

### `getPayout(address _qToken, uint256 _amount) → bool isSettled, address payoutToken, uint256 payoutAmount` (public)

### `OptionsPositionMinted(address account, address qToken, uint256 optionsAmount)`

### `SpreadMinted(address account, address qTokenToMint, address qTokenForCollateral, uint256 optionsAmount)`

### `OptionsExercised(address account, address qToken, uint256 amountExercised, uint256 payout, address payoutAsset)`

### `NeutralizePosition(address account, address qToken, uint256 amountNeutralized, uint256 collateralReclaimed, address collateralAsset, address longTokenReturned)`

### `CollateralClaimed(address account, uint256 collateralTokenId, uint256 amountClaimed, uint256 collateralReturned, address collateralAsset)`
