// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "../../external/chainlink/IEACAggregatorProxy.sol";

/// @title Mock chainlink proxy
contract MockAggregatorProxy is IEACAggregatorProxy {
    struct LatestRoundData {
        uint80 roundId;
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }

    mapping(uint256 => uint256) roundTimestamps;
    mapping(uint256 => int256) roundIdAnswers;
    LatestRoundData latestRoundDataValue;
    int256 latestAnswerValue;
    uint256 latestTimestampValue;

    function setTimestamp(uint256 _round, uint256 _timestamp) external {
        roundTimestamps[_round] = _timestamp;
    }

    function setRoundIdAnswer(uint256 _roundId, int256 _answer) external {
        roundIdAnswers[_roundId] = _answer;
    }

    function setLatestRoundData(LatestRoundData calldata _latestRoundData)
        external
    {
        latestRoundDataValue = _latestRoundData;
    }

    function setLatestAnswer(int256 _latestAnswer) external {
        latestAnswerValue = _latestAnswer;
    }

    function setLatestTimestamp(uint256 _latestTimestamp) external {
        latestTimestampValue = _latestTimestamp;
    }

    function acceptOwnership() external override {
        //noop
    }

    function confirmAggregator(address _aggregator) external override {
        //noop
    }

    function proposeAggregator(address _aggregator) external override {
        //noop
    }

    function setController(address _accessController) external override {
        //noop
    }

    function transferOwnership(address _to) external override {
        //noop
    }

    function accessController() external view override returns (address) {
        return address(0);
    }

    function aggregator() external view override returns (address) {
        return address(0);
    }

    function decimals() external view override returns (uint8) {
        return 0;
    }

    function description() external view override returns (string memory) {
        return "...";
    }

    function getAnswer(uint256 _roundId)
        external
        view
        override
        returns (int256)
    {
        return roundIdAnswers[_roundId];
    }

    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (0, 0, 0, 0, 0);
    }

    function getTimestamp(uint256 _roundId)
        external
        view
        override
        returns (uint256)
    {
        return roundTimestamps[_roundId];
    }

    function latestAnswer() external view override returns (int256) {
        return latestAnswerValue;
    }

    function latestRound() external view override returns (uint256) {
        return 0;
    }

    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
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

    function owner() external view override returns (address) {
        return address(0);
    }

    function phaseAggregators(uint16) external view override returns (address) {
        return address(0);
    }

    function phaseId() external view override returns (uint16) {
        return 0;
    }

    function proposedAggregator() external view override returns (address) {
        return address(0);
    }

    function proposedGetRoundData(uint80 _roundId)
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (0, 0, 0, 0, 0);
    }

    function proposedLatestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (0, 0, 0, 0, 0);
    }

    function version() external view override returns (uint256) {
        return 0;
    }
}
