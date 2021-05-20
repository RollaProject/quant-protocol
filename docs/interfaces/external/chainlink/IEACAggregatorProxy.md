## `IEACAggregatorProxy`

### `acceptOwnership()` (external)

### `confirmAggregator(address _aggregator)` (external)

### `proposeAggregator(address _aggregator)` (external)

### `setController(address _accessController)` (external)

### `transferOwnership(address _to)` (external)

### `accessController() → address` (external)

### `aggregator() → address` (external)

### `decimals() → uint8` (external)

### `description() → string` (external)

### `getAnswer(uint256 _roundId) → int256` (external)

### `getRoundData(uint80 _roundId) → uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound` (external)

### `getTimestamp(uint256 _roundId) → uint256` (external)

### `latestAnswer() → int256` (external)

### `latestRound() → uint256` (external)

### `latestRoundData() → uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound` (external)

### `latestTimestamp() → uint256` (external)

### `owner() → address` (external)

### `phaseAggregators(uint16) → address` (external)

### `phaseId() → uint16` (external)

### `proposedAggregator() → address` (external)

### `proposedGetRoundData(uint80 _roundId) → uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound` (external)

### `proposedLatestRoundData() → uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound` (external)

### `version() → uint256` (external)

### `AnswerUpdated(int256 current, uint256 roundId, uint256 updatedAt)`

### `NewRound(uint256 roundId, address startedBy, uint256 startedAt)`

### `OwnershipTransferRequested(address from, address to)`

### `OwnershipTransferred(address from, address to)`
