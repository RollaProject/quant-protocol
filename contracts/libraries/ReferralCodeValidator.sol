// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

library ReferralCodeValidator {
    /**
     * filters referral codes
     * converts uppercase to lower case.
     * cannot start with 0x
     * restricts characters to A-Z, a-z, 0-9.
     * @param _referralCode referral code to validate
     * @return convertedCode reprocessed string in bytes32 format
     */
    function validateCode(string memory _referralCode)
        internal
        pure
        returns (bytes32 convertedCode)
    {
        bytes memory inputBytes = bytes(_referralCode);
        uint256 length = inputBytes.length;

        require(
            length > 0 && length <= 32,
            "string must be between 1 and 32 characters"
        );

        // make sure first two characters are not 0x
        if (inputBytes[0] == 0x30) {
            require(inputBytes[1] != 0x78, "string cannot start with 0x");
            require(inputBytes[1] != 0x58, "string cannot start with 0X");
        }

        // convert & check
        for (uint256 i = 0; i < length; i++) {
            // if its uppercase A-Z
            if (inputBytes[i] > 0x40 && inputBytes[i] < 0x5b) {
                // convert to lower case a-z
                inputBytes[i] = byte(uint8(inputBytes[i]) + 32);
            } else {
                //allow lower case a-z or 0-9
                require(
                    (inputBytes[i] > 0x60 && inputBytes[i] < 0x7b) ||
                        (inputBytes[i] > 0x2f && inputBytes[i] < 0x3a),
                    "string contains invalid characters"
                );
            }
        }

        assembly {
            convertedCode := mload(add(inputBytes, 32))
        }
    }
}
