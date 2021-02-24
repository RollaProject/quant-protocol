// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "hardhat/console.sol";
import "./IEACAggregatorProxy.sol";

contract RoundIdTest {
    IEACAggregatorProxy private constant _AGGREGATOR =
        IEACAggregatorProxy(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    function getLastValidRound(uint256 roundId)
        external
        view
        returns (uint256)
    {
        // This is the roundId that's in the aggregator implementation contract
        uint64 previousRoundId = uint64(roundId);

        uint16 phaseOffset = 64;
        uint16 phaseId = uint16(roundId >> phaseOffset);

        // This is the roundId that's in the aggregator proxy contract
        uint80 previousRound =
            uint80((uint256(phaseId) << phaseOffset) | previousRoundId);

        uint256 previousTimestamp =
            _AGGREGATOR.getTimestamp(uint256(previousRound));

        return previousTimestamp;
    }
}
