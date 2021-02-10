## `QToken`

### `onlyOptionsController(string _message)`

Only allow the OptionsFactory or governance/admin to call a certain function

### `constructor(address _quantConfig, address _underlyingAsset, address _strikeAsset, uint256 _strikePrice, uint256 _expiryTime, bool _isCall)` (public)

### `mint(address account, uint256 amount)` (external)

mint option token for an account

Controller only method where access control is taken care of by \_beforeTokenTransfer hook

### `burn(address account, uint256 amount)` (external)

burn option token from an account.

Controller only method where access control is taken care of by \_beforeTokenTransfer hook
