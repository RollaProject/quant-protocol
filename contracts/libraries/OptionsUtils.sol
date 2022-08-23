// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "solady/src/utils/LibString.sol";
import "@quant-finance/solidity-datetime/contracts/DateTime.sol";
import "../options/QToken.sol";
import "../interfaces/IOracleRegistry.sol";
import "../interfaces/IProviderOracleManager.sol";
import "../interfaces/IQToken.sol";
import "../interfaces/IAssetsRegistry.sol";

/// @title Options utilities for Quant's QToken and CollateralToken
/// @author Rolla
library OptionsUtils {
    /// @notice salt to be used with CREATE2 when creating new options
    /// @dev constant salt because options will only be deployed with the same parameters once
    bytes32 internal constant SALT = bytes32("ROLLA.FINANCE");

    uint8 internal constant STRIKE_PRICE_DECIMALS = 18;

    uint8 internal constant OPTIONS_DECIMALS = 18;

    // abi.encodeWithSignature("DataSizeLimitExceeded(uint256)");
    uint256 internal constant DataSizeLimitExceeded_error_signature =
        0x5307a82000000000000000000000000000000000000000000000000000000000;

    uint256 internal constant DataSizeLimitExceeded_error_sig_ptr = 0x0;

    uint256 internal constant DataSizeLimitExceeded_error_datasize_ptr = 0x4;

    uint256 internal constant DataSizeLimitExceeded_error_length = 0x24; // 4 + 32 == 36

    /// @notice Checks if the given option parameters are valid for creation in the Quant Protocol
    /// @param _assetProperties underlying asset properties as stored in the AssetsRegistry contract
    /// @param _oracleRegistry oracle registry to validate the passed _oracle against
    /// @param _underlyingAsset asset that the option is for
    /// @param _oracle price oracle for the option underlying
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _strikePrice strike price with as many decimals in the strike asset
    function validateOptionParameters(
        bytes memory _assetProperties,
        address _oracleRegistry,
        address _underlyingAsset,
        address _oracle,
        uint88 _expiryTime,
        uint256 _strikePrice
    )
        internal
        view
    {
        require(_expiryTime > block.timestamp, "OptionsFactory: given expiry time is in the past");

        require(
            IProviderOracleManager(_oracle).isValidOption(_underlyingAsset, _expiryTime, _strikePrice),
            "OptionsFactory: Oracle doesn't support the given option"
        );

        require(
            IOracleRegistry(_oracleRegistry).isOracleActive(_oracle),
            "OptionsFactory: Oracle is not active in the OracleRegistry"
        );

        require(_strikePrice > 0, "strike can't be 0");

        bool isRegistered;
        assembly ("memory-safe") {
            // The isRegistered bool is the fourth property in assetProperties,
            // thus, it's located at assetProperties + 0x60
            isRegistered := mload(add(_assetProperties, 0x60))
        }
        require(isRegistered, "underlying not in the registry");
    }

    /// @notice Gets the amount of decimals for an option exercise payout
    /// @param _qToken address of the option's QToken contract
    /// @param _assetsRegistry address of the AssetsRegistry contract
    /// @return payoutDecimals amount of decimals for the option exercise payout
    function getPayoutDecimals(IQToken _qToken, address _assetsRegistry) internal view returns (uint8 payoutDecimals) {
        if (_qToken.isCall()) {
            (,, payoutDecimals,) = IAssetsRegistry(_assetsRegistry).assetProperties(_qToken.underlyingAsset());
        } else {
            payoutDecimals = STRIKE_PRICE_DECIMALS;
        }
    }

    function getAssetProperties(address _asset, address _assetsRegistry)
        internal
        view
        returns (bytes memory assetProperties)
    {
        bytes memory calld = abi.encodeCall(IAssetsRegistry.assetProperties, (_asset));

        assembly ("memory-safe") {
            assetProperties := mload(0x40)

            pop(staticcall(gas(), _assetsRegistry, add(calld, 0x20), mload(calld), 0, 0))

            let returnLen := returndatasize()

            returndatacopy(assetProperties, 0, returnLen)

            mstore(0x40, add(assetProperties, returnLen))
        }
    }

    /// @notice generates the name and symbol for an option and adds them to the immutable args
    /// in memory starting at the given pointer
    /// @param assetProperties pointer to the underlying asset properties in memory
    /// @param immutableArgsData pointer to the start of the clone immutable args data in memory
    function addNameAndSymbolToImmutableArgs(bytes memory assetProperties, bytes memory immutableArgsData)
        internal
        pure
    {
        string memory underlying;
        string memory displayStrikePrice;
        string memory typeSymbol;
        string memory typeFull;
        string memory monthSymbol;
        string memory monthFull;
        string memory dayStr;
        string memory yearStr;
        {
            address underlyingAsset;
            uint88 expiryTime;
            bool isCall;
            uint256 strikePrice;

            // get the individual values from the packed args in memory
            assembly ("memory-safe") {
                // the packed args length is stored at immutableArgsData + 0x100
                // and the packed args contents start at immutableArgsData + 0x120
                let encodedArgsStart := add(immutableArgsData, 0x120)

                /* packed args memory layout, starting at encodedArgsStart:
                0x00: OPTIONS_DECIMALS |   (uint8 == 1 byte)
                0x01: underlyingAsset  | (address == 20 bytes)
                0x15: strikeAsset      | (address == 20 bytes)
                0x29: oracle           | (address == 20 bytes)
                0x3d: expiryTime       |  (uint88 == 11 bytes)
                0x48: isCall           |    (bool == 1 byte)
                0x49: strikePrice      | (uint256 == 32 bytes)
                0x69: controller       | (address == 20 bytes)
                */

                underlyingAsset := shr(96, mload(add(encodedArgsStart, 0x01)))

                expiryTime := shr(168, mload(add(encodedArgsStart, 0x3d)))

                isCall := shr(248, mload(add(encodedArgsStart, 0x48)))

                strikePrice := mload(add(encodedArgsStart, 0x49))

                if shr(128, strikePrice) { strikePrice := and(1, strikePrice) }

                // The underlying asset symbol is the second property in assetProperties,
                // thus, it's located at assetProperties + 0x20
                underlying := add(assetProperties, mload(add(assetProperties, 0x20)))
            }

            displayStrikePrice = displayedStrikePrice(strikePrice);

            // get option type string
            (typeSymbol, typeFull) = getOptionType(isCall);

            // convert the expiry to a readable string
            (uint256 year, uint256 month, uint256 day) = DateTime.timestampToDate(expiryTime);

            // get option month string
            (monthSymbol, monthFull) = getMonth(month);

            // get the day and year strings
            dayStr = getDayStr(day);
            yearStr = LibString.toString(year);
        }

        // for the current free memory pointer, after the packed args and all the strings
        // generated and allocated above
        uint256 newFreeMemPtr;

        assembly ("memory-safe") {
            // save the current free memory pointer so that it can be restored later after
            // all the free memory pointer manipulations are done
            newFreeMemPtr := mload(0x40)

            // clear the 32 bytes where the packed args length was previously stored
            mstore(add(immutableArgsData, 0x100), 0)

            // set the free memory pointer to 128 bytes before the immutable args length
            // so that the symbol string gets stored in that space
            mstore(0x40, add(immutableArgsData, 0x80))
        }

        // generate, allocate and store the symbol string right before the packed args
        string memory metadata = string.concat(
            "ROLLA", "-", underlying, "-", dayStr, monthSymbol, yearStr, "-", displayStrikePrice, "-", typeSymbol
        );

        normalizeStringImmutableArg(metadata);

        assembly ("memory-safe") {
            // clear the 32 bytes where the symbol string length was stored
            mstore(add(immutableArgsData, 0x80), 0)

            // set the free memory pointer to 128 bytes before the symbol string
            // so that the name string gets stored in that space
            mstore(0x40, immutableArgsData)
        }

        // generate, allocate and store the name string right before the symbol string
        metadata = string.concat(
            "ROLLA", " ", underlying, " ", dayStr, "-", monthFull, "-", yearStr, " ", displayStrikePrice, " ", typeFull
        );

        normalizeStringImmutableArg(metadata);

        assembly ("memory-safe") {
            // store the total QToken immutable arguments size at its pointer,
            // overriding the previous name string length that was stored there
            mstore(immutableArgsData, 0x017d) // 381 bytes

            // restore the free memory pointer
            mstore(0x40, newFreeMemPtr)
        }
    }

    /// @notice Normalize a string in memory so that it occupies 128 bytes to be
    /// used with the ClonesWithImmutableArgs library. The last (128th) byte stores
    /// the length of the string, and the first 127 bytes store the actual string content.
    function normalizeStringImmutableArg(string memory s) internal pure {
        assembly ("memory-safe") {
            // get the original length of the string
            let len := mload(s)

            // end execution with a custom DataSizeLimitExceeded error if the input data
            // is larger than 127 bytes
            if gt(len, 0x7f) {
                mstore(DataSizeLimitExceeded_error_sig_ptr, DataSizeLimitExceeded_error_signature)
                mstore(DataSizeLimitExceeded_error_datasize_ptr, len)
                revert(DataSizeLimitExceeded_error_sig_ptr, DataSizeLimitExceeded_error_length)
            }

            // store the new length of the string as 128 bytes
            mstore(s, 0x80)

            // store the original length of the string in the last byte of the output
            // location in memory, i.e. the 128th byte
            mstore(add(s, 0x80), xor(mload(add(s, 0x80)), shl(0xf8, len)))
        }
    }

    /// @dev convert the option strike price scaled to a human readable value
    /// @param _strikePrice the option strike price scaled by the strike asset decimals
    /// @return strike price string
    function displayedStrikePrice(uint256 _strikePrice) internal pure returns (string memory) {
        unchecked {
            uint256 strikePriceScale = 10 ** STRIKE_PRICE_DECIMALS;
            uint256 remainder = _strikePrice % strikePriceScale;
            uint256 quotient = _strikePrice / strikePriceScale;
            string memory quotientStr = LibString.toString(quotient);

            if (remainder == 0) {
                return quotientStr;
            }

            uint256 trailingZeroes;
            while (remainder % 10 == 0) {
                remainder /= 10;
                trailingZeroes++;
            }

            // pad the number with "1 + starting zeroes"
            remainder += 10 ** (STRIKE_PRICE_DECIMALS - trailingZeroes);

            string memory tmp = LibString.toString(remainder);
            tmp = slice(tmp, 1, 1 + STRIKE_PRICE_DECIMALS - trailingZeroes);

            return string(abi.encodePacked(quotientStr, ".", tmp));
        }
    }

    /// @dev get the string representation of the option type
    /// @return a 1 character representation of the option type
    /// @return a full length string of the option type
    function getOptionType(bool _isCall) internal pure returns (string memory, string memory) {
        return _isCall ? ("C", "Call") : ("P", "Put");
    }

    /// @dev get the representation of a day's number using 2 characters,
    /// adding a leading 0 if it's a one digit number
    /// @return dayStr 2 characters that correspond to a day's number
    function getDayStr(uint256 day) internal pure returns (string memory dayStr) {
        assembly ("memory-safe") {
            dayStr := mload(0x40)
            mstore(0x40, add(dayStr, 0x22))
            mstore(dayStr, 0x2)

            switch lt(day, 10)
            case 0 {
                mstore8(add(dayStr, 0x20), add(0x30, mod(div(day, 10), 10)))
                mstore8(add(dayStr, 0x21), add(0x30, mod(day, 10)))
            }
            default {
                mstore8(add(dayStr, 0x20), 0x30)
                mstore8(add(dayStr, 0x21), add(0x30, day))
            }
        }
    }

    /// @dev cut a string into string[start:end]
    /// @param _s string to cut
    /// @param _start the starting index
    /// @param _end the ending index (not inclusive)
    /// @return slice_ the indexed string
    function slice(string memory _s, uint256 _start, uint256 _end) internal pure returns (string memory slice_) {
        assembly ("memory-safe") {
            slice_ := add(_s, _start)
            mstore(slice_, sub(_end, _start))
        }
    }

    /// @dev get the string representations of a month
    /// @return a 3 character representation
    /// @return a full length string representation
    function getMonth(uint256 _month) internal pure returns (string memory, string memory) {
        if (_month == 1) {
            return ("JAN", "January");
        } else if (_month == 2) {
            return ("FEB", "February");
        } else if (_month == 3) {
            return ("MAR", "March");
        } else if (_month == 4) {
            return ("APR", "April");
        } else if (_month == 5) {
            return ("MAY", "May");
        } else if (_month == 6) {
            return ("JUN", "June");
        } else if (_month == 7) {
            return ("JUL", "July");
        } else if (_month == 8) {
            return ("AUG", "August");
        } else if (_month == 9) {
            return ("SEP", "September");
        } else if (_month == 10) {
            return ("OCT", "October");
        } else if (_month == 11) {
            return ("NOV", "November");
        } else if (_month == 12) {
            return ("DEC", "December");
        } else {
            revert("OptionsUtils: invalid month");
        }
    }
}
