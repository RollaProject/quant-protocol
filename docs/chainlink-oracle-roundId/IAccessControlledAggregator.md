## `IAccessControlledAggregator`

### `acceptAdmin(address _oracle)` (external)

### `acceptOwnership()` (external)

### `addAccess(address _user)` (external)

### `changeOracles(address[] _removed, address[] _added, address[] _addedAdmins, uint32 _minSubmissions, uint32 _maxSubmissions, uint32 _restartDelay)` (external)

### `disableAccessCheck()` (external)

### `enableAccessCheck()` (external)

### `onTokenTransfer(address, uint256, bytes _data)` (external)

### `removeAccess(address _user)` (external)

### `setRequesterPermissions(address _requester, bool _authorized, uint32 _delay)` (external)

### `setValidator(address _newValidator)` (external)

### `submit(uint256 _roundId, int256 _submission)` (external)

### `transferAdmin(address _oracle, address _newAdmin)` (external)

### `transferOwnership(address _to)` (external)

### `updateAvailableFunds()` (external)

### `updateFutureRounds(uint128 _paymentAmount, uint32 _minSubmissions, uint32 _maxSubmissions, uint32 _restartDelay, uint32 _timeout)` (external)

### `withdrawFunds(address _recipient, uint256 _amount)` (external)

### `withdrawPayment(address _oracle, address _recipient, uint256 _amount)` (external)

### `requestNewRound() → uint80` (external)

### `allocatedFunds() → uint128` (external)

### `availableFunds() → uint128` (external)

### `checkEnabled() → bool` (external)

### `decimals() → uint8` (external)

### `description() → string` (external)

### `getAdmin(address _oracle) → address` (external)

### `getAnswer(uint256 _roundId) → int256` (external)

### `getOracles() → address[]` (external)

### `getRoundData(uint80 _roundId) → uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound` (external)

### `getTimestamp(uint256 _roundId) → uint256` (external)

### `hasAccess(address _user, bytes _calldata) → bool` (external)

### `latestAnswer() → int256` (external)

### `latestRound() → uint256` (external)

### `latestRoundData() → uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound` (external)

### `latestTimestamp() → uint256` (external)

### `linkToken() → address` (external)

### `maxSubmissionCount() → uint32` (external)

### `maxSubmissionValue() → int256` (external)

### `minSubmissionCount() → uint32` (external)

### `minSubmissionValue() → int256` (external)

### `oracleCount() → uint8` (external)

### `oracleRoundState(address _oracle, uint32 _queriedRoundId) → bool _eligibleToSubmit, uint32 _roundId, int256 _latestSubmission, uint64 _startedAt, uint64 _timeout, uint128 _availableFunds, uint8 _oracleCount, uint128 _paymentAmount` (external)

### `owner() → address` (external)

### `paymentAmount() → uint128` (external)

### `restartDelay() → uint32` (external)

### `timeout() → uint32` (external)

### `validator() → address` (external)

### `version() → uint256` (external)

### `withdrawablePayment(address _oracle) → uint256` (external)

### `AddedAccess(address user)`

### `AnswerUpdated(int256 current, uint256 roundId, uint256 updatedAt)`

### `AvailableFundsUpdated(uint256 amount)`

### `CheckAccessDisabled()`

### `CheckAccessEnabled()`

### `NewRound(uint256 roundId, address startedBy, uint256 startedAt)`

### `OracleAdminUpdateRequested(address oracle, address admin, address newAdmin)`

### `OracleAdminUpdated(address oracle, address newAdmin)`

### `OraclePermissionsUpdated(address oracle, bool whitelisted)`

### `OwnershipTransferRequested(address from, address to)`

### `OwnershipTransferred(address from, address to)`

### `RemovedAccess(address user)`

### `RequesterPermissionsSet(address requester, bool authorized, uint32 delay)`

### `RoundDetailsUpdated(uint128 paymentAmount, uint32 minSubmissionCount, uint32 maxSubmissionCount, uint32 restartDelay, uint32 timeout)`

### `SubmissionReceived(int256 submission, uint32 round, address oracle)`

### `ValidatorUpdated(address previous, address current)`
