// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "hardhat/console.sol";
import "../../../external/chainlink/IEACAggregatorProxy.sol";

contract RoundIdTest {
    using SafeMath for uint256;

    IEACAggregatorProxy private constant _AGGREGATOR = IEACAggregatorProxy(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    function submitPrice(uint256 expiryTimestamp, uint8 maxIterations) external {
        (uint80 latestRound,,,,) = _AGGREGATOR.latestRoundData();

        //search and get round
        uint80 roundAfterExpiry = searchRoundToSubmit(expiryTimestamp, latestRound, maxIterations);

        //submit price to registry
        getRoundPriceAndSubmitToRegistry(expiryTimestamp, roundAfterExpiry);
    }

    function searchRoundToSubmit(uint256 expiryTimestamp, uint80 latestRound, uint8 maxIterations) public view returns(uint80) {
        uint16 phaseOffset = 64;
        uint16 phaseId = uint16(latestRound >> phaseOffset);

        uint80 lowestPossibleRound = uint80((phaseId << phaseOffset) | 1);
        uint80 highestPossibleRound = latestRound;
        uint80 firstId = 0;
        uint80 lastId = 0;

        //binary search until we find two values our desired timestamp lies between
        for (uint8 i = 0; i < maxIterations; i++) {
            (lowestPossibleRound, highestPossibleRound, firstId, lastId) = _binarySearchStep(
                expiryTimestamp,
                lowestPossibleRound,
                highestPossibleRound
            );

            if((lastId - firstId) == 1) {
                break; //terminate loop as the rounds are adjacent
            }
        }

        //check which one of the values is above the round we care about
        return highestPossibleRound;
    }

    function _binarySearchStep(
        uint256 _expiryTimestamp,
        uint80 _firstRoundProxy,
        uint80 _lastRoundProxy
    ) internal view returns (uint80 firstRound, uint80 lastRound, uint80 firstRoundProxy, uint80 lastRoundProxy) {
        uint16 phaseOffset = 64;
        uint16 phaseId = uint16(_lastRoundProxy >> phaseOffset);

        uint64 lastRoundId = uint64(_lastRoundProxy);
        uint64 firstRoundId = uint64(_firstRoundProxy);

        console.log("=========================================");
        console.log("Timestamp to Find: ", _expiryTimestamp);

        console.log("First Round ID: ", firstRoundId);

        uint80 roundToCheck = _toUint80(uint256(firstRoundId).add(uint256(lastRoundId)).div(2));

        console.log("Round to check: ", roundToCheck);
        console.log("Last Round ID: ", lastRoundId);

        uint80 roundToCheckProxy = uint80((uint256(phaseId) << phaseOffset) | roundToCheck);

        console.log("First Round Proxy: ", _firstRoundProxy);
        console.log("Round to Check Proxy: ", roundToCheckProxy);
        console.log("Last Round Proxy: ", _lastRoundProxy);

        uint256 firstRoundTimestamp = _AGGREGATOR.getTimestamp(uint256(_firstRoundProxy));
        console.log("Previous Round Timestamp: ", firstRoundTimestamp);

        uint256 roundToCheckTimestamp = _AGGREGATOR.getTimestamp(uint256(roundToCheckProxy));
        console.log("Round to Check Timestamp: ", roundToCheckTimestamp);

        uint256 lastRoundTimestamp = _AGGREGATOR.getTimestamp(uint256(_lastRoundProxy));
        console.log("Last Round Timestamp: ", lastRoundTimestamp);

        console.log("=========================================");

        if(roundToCheckTimestamp <= _expiryTimestamp) {
            return (roundToCheckProxy, _lastRoundProxy, roundToCheck, lastRoundId);
        }

        return (_firstRoundProxy, roundToCheckProxy, firstRoundId, roundToCheck);
    }

    function getRoundPriceAndSubmitToRegistry(uint256 expiryTimestamp, uint80 roundId) public {
        require(
            _AGGREGATOR.getTimestamp(uint256(roundId)) > expiryTimestamp,
            "RoundIdTest: The round submitted is not after the expiry timestamp"
        );

        uint16 phaseOffset = 64;
        uint16 phaseId = uint16(roundId >> phaseOffset);

        uint64 roundBefore = uint64(roundId) - 1;
        uint80 roundBeforeId = uint80((uint256(phaseId) << phaseOffset) | roundBefore);

        require(
            _AGGREGATOR.getTimestamp(uint256(roundBeforeId)) <= expiryTimestamp,
            "RoundIdTest: The round before the submitted round is not before or equal to the expiry timestamp"
        );

        //todo submit the price to our registry...
        console.log("Round After", roundId);
    }

    /**
     * @dev Returns the downcasted uint80 from uint256, reverting on
     * overflow (when the input is greater than largest uint80).
     *
     * Counterpart to Solidity's `uint80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     */
    function _toUint80(uint256 value) internal pure returns (uint80) {
        require(value < 2**80, "SafeCast: value doesn\'t fit in 80 bits");
        return uint80(value);
    }
}
