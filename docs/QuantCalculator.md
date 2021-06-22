## `QuantCalculator`

### `constructor(address _optionsFactory)` (public)

### `calculateClaimableCollateral(uint256 _collateralTokenId, uint256 _amount, address _msgSender) → uint256 returnableCollateral, address collateralAsset, uint256 amountToClaim` (external)

### `getNeutralizationPayout(address _qTokenShort, address _qTokenLong, uint256 _amountToNeutralize) → address collateralType, uint256 collateralOwed` (external)

### `getCollateralRequirement(address _qTokenToMint, address _qTokenForCollateral, uint256 _amount) → address collateral, uint256 collateralAmount` (external)

### `getExercisePayout(address _qToken, uint256 _amount) → bool isSettled, address payoutToken, uint256 payoutAmount` (external)
