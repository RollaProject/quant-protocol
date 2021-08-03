// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.0;

import "../libraries/ReferralCodeValidator.sol";

contract ReferralCodeValidatorTester {
    function testValidateCode(string memory referralCode)
        external
        pure
        returns (bytes32)
    {
        return ReferralCodeValidator.validateCode(referralCode);
    }
}
