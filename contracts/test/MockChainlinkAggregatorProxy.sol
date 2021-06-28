// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

contract MockChainlinkAggregatorProxy {
    int256 private _defaultLatestAnswer;

    constructor(int256 defaultLatestAnswer_) {
        _defaultLatestAnswer = defaultLatestAnswer_;
    }

    function latestAnswer() external view returns (int256) {
        return _defaultLatestAnswer;
    }
}
