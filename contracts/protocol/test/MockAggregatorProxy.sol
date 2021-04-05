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

    function setLatestRoundData(LatestRoundData calldata _latestRoundData) external {
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

    function accessController() external override view returns (address) {
        return address(0);
    }

    function aggregator() external override view returns (address) {
        return address(0);
    }

    function decimals() external override view returns (uint8) {
        return 0;
    }

    function description() external override view returns (string memory) {
        return "...";
    }

    function getAnswer(uint256 _roundId) external override view returns (int256) {
        return roundIdAnswers[_roundId];
    }

    function getRoundData(uint80 _roundId)
    external override
    view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (0,0,0,0,0);
    }

    function getTimestamp(uint256 _roundId) external override view returns (uint256){
        return roundTimestamps[_roundId];
    }

    function latestAnswer() external override view returns (int256) {
        return latestAnswerValue;
    }

    function latestRound() external override view returns (uint256) {
        return 0;
    }

    function latestRoundData()
    external override
    view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (
            latestRoundDataValue.roundId,
            latestRoundDataValue.answer,
            latestRoundDataValue.startedAt,
            latestRoundDataValue.updatedAt,
            latestRoundDataValue.answeredInRound
        );
    }

    function latestTimestamp() external override view returns (uint256) {
        return latestTimestampValue;
    }

    function owner() external override view returns (address) {
        return address(0);
    }

    function phaseAggregators(uint16) external override view returns (address) {
        return address(0);
    }

    function phaseId() external override view returns (uint16) {
        return 0;
    }

    function proposedAggregator() external override view returns (address) {
        return address(0);
    }

    function proposedGetRoundData(uint80 _roundId)
    external override
    view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (0,0,0,0,0);
    }

    function proposedLatestRoundData()
    external override
    view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (0,0,0,0,0);
    }

    function version() external override view returns (uint256) {
        return 0;
    }
}
