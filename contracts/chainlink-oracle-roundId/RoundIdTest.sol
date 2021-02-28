// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "hardhat/console.sol";
import "./IEACAggregatorProxy.sol";

contract RoundIdTest {
    IEACAggregatorProxy private constant _AGGREGATOR =
        IEACAggregatorProxy(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    function getLastValidRoundLoop(uint256 roundId) public view {
        for (uint256 i = 0; i < 3; i++) {
            getLastValidRound(roundId - i);
        }
    }

    function getLastValidRound(uint256 roundId) public view returns (uint256) {
        console.log("Round ID: ", roundId);

        uint256 roundTimestamp = _AGGREGATOR.getTimestamp(uint256(roundId));

        console.log("Round Timestamp: ", roundTimestamp);

        // This is the roundId that's in the aggregator implementation contract
        uint64 previousRoundId = uint64(roundId - 1);

        console.log("Previous Round ID: ", previousRoundId);

        uint16 phaseOffset = 64;
        uint16 phaseId = uint16(roundId >> phaseOffset);

        // This is the roundId that's in the aggregator proxy contract
        uint80 previousRound =
            uint80((uint256(phaseId) << phaseOffset) | previousRoundId);

        console.log("Previous Round: ", previousRound);

        uint256 previousTimestamp =
            _AGGREGATOR.getTimestamp(uint256(previousRound));

        console.log("Previous Round Timestamp: ", previousTimestamp);

        //return previousTimestamp;
        return previousRound;
    }
}
