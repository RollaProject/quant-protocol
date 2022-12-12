// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "../interfaces/external/chainlink/IEACAggregatorProxy.sol";

/// @title Mock chainlink proxy
/// @author Rolla
contract MockAggregatorProxy is IEACAggregatorProxy {
    struct RoundData {
        uint80 roundId;
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }

    mapping(uint256 => uint256) public roundTimestamps;
    mapping(uint256 => int256) public roundIdAnswers;
    mapping(uint80 => RoundData) public roundData;
    RoundData public latestRoundDataValue;
    int256 public latestAnswerValue;
    uint256 public latestTimestampValue;
    uint256 public latestRoundValue;

    function setTimestamp(uint256 _round, uint256 _timestamp) external {
        roundTimestamps[_round] = _timestamp;
    }

    function setRoundIdAnswer(uint256 _roundId, int256 _answer) external {
        roundIdAnswers[_roundId] = _answer;
    }

    function setLatestRoundData(RoundData calldata _latestRoundData) external {
        latestRoundDataValue = _latestRoundData;
    }

    function setLatestAnswer(int256 _latestAnswer) external {
        latestAnswerValue = _latestAnswer;
    }

    function setLatestTimestamp(uint256 _latestTimestamp) external {
        latestTimestampValue = _latestTimestamp;
    }

    function setLatestRound(uint256 _latestRound) external {
        latestRoundValue = _latestRound;
    }

    function setRoundData(RoundData calldata _roundData) external {
        roundData[_roundData.roundId] = _roundData;
    }

    function getAnswer(uint256 _roundId) external view override returns (int256) {
        return roundIdAnswers[_roundId];
    }

    function getTimestamp(uint256 _roundId) external view override returns (uint256) {
        return roundTimestamps[_roundId];
    }

    function latestAnswer() external view override returns (int256) {
        return latestAnswerValue;
    }

    function latestRound() external view override returns (uint256) {
        return latestRoundValue;
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (
            latestRoundDataValue.roundId,
            latestRoundDataValue.answer,
            latestRoundDataValue.startedAt,
            latestRoundDataValue.updatedAt,
            latestRoundDataValue.answeredInRound
        );
    }

    function latestTimestamp() external view override returns (uint256) {
        return latestTimestampValue;
    }

    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        RoundData memory data = roundData[_roundId];
        return (data.roundId, data.answer, data.startedAt, data.updatedAt, data.answeredInRound);
    }

    function accessController() external pure override returns (address) {
        return address(0);
    }

    function aggregator() external pure override returns (address) {
        return address(0);
    }

    function decimals() external pure override returns (uint8) {
        return 8;
    }

    function description() external pure override returns (string memory) {
        return "...";
    }

    function owner() external pure override returns (address) {
        return address(0);
    }

    function phaseAggregators(uint16) external pure override returns (address) {
        return address(0);
    }

    function phaseId() external pure override returns (uint16) {
        return 0;
    }

    function proposedAggregator() external pure override returns (address) {
        return address(0);
    }

    function proposedGetRoundData(uint80)
        external
        pure
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (0, 0, 0, 0, 0);
    }

    function proposedLatestRoundData()
        external
        pure
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (0, 0, 0, 0, 0);
    }

    function version() external pure override returns (uint256) {
        return 0;
    }
}
