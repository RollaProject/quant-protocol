// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "./IEACAggregatorProxy.sol";

contract RoundIdTest {
    IEACAggregatorProxy private constant _AGGREGATOR =
        IEACAggregatorProxy(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    function getLastValidRound(uint256 roundId)
        external
        view
        returns (uint256)
    {
        // Get the roundId corresponding to the current round of the aggregator implementation
        // This is the upper bound of what we'll search
        uint64 lastRoundId = uint64(roundId);

        // Get the timestamp of round 1
        uint16 phaseOffset = 64;
        uint16 phaseId = uint16(lastRoundId >> phaseOffset);
        uint80 firstRound = uint80((phaseId << phaseOffset) | 1);
        uint256 firstTimestamp = _AGGREGATOR.getTimestamp(uint256(firstRound));

        return firstTimestamp;
    }
}
