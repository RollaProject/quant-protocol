// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "solady/src/utils/LibString.sol";
import "@quant-finance/solidity-datetime/contracts/DateTime.sol";
import "../options/QToken.sol";
import "../interfaces/IOracleRegistry.sol";
import "../interfaces/IProviderOracleManager.sol";
import "../interfaces/IQToken.sol";
import "../interfaces/IAssetsRegistry.sol";

uint8 constant OPTIONS_DECIMALS = 18;
uint256 constant ONE_WORD = 0x20;
uint256 constant FREE_MEM_PTR = 0x40;
uint256 constant IMMUTABLE_STRING_LENGTH = 128;
uint256 constant NAME_AND_SYMBOL_LENGTH = 256;
uint256 constant MAX_STRING_LENGTH = 127;
uint256 constant PACKED_ARGS_LENGTH = 125;
uint256 constant IMMUTABLE_ARGS_LENGTH = 381;
uint256 constant MASK_1 = 2 ** (1) - 1;
uint256 constant MASK_8 = 2 ** (8) - 1;
uint256 constant MASK_88 = 2 ** (88) - 1;
uint256 constant MASK_160 = 2 ** (160) - 1;
uint256 constant MASK_256 = 2 ** (256) - 1;
uint256 constant ADDRESS_OFFSET = 96;
uint256 constant ONE_BYTE_OFFSET = 248;
uint256 constant UINT88_OFFSET = 168;

/// @title Options utilities for Quant's QToken and CollateralToken
/// @author Rolla
library OptionsUtils {
    /// @notice salt to be used with CREATE2 when creating new options
    /// @dev constant salt because options will only be deployed with the same parameters once
    bytes32 internal constant SALT = bytes32("ROLLA.FINANCE");

    uint8 internal constant STRIKE_PRICE_DECIMALS = 18;

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

    /// @notice Gets the properties for an asset stored in the AssetsRegistry
    /// @param _asset address of the asset to get the properties for
    /// @param _assetsRegistry address of the AssetsRegistry to read the properties from
    /// @return assetProperties the properties read from the AssetsRegistry and copied to memory
    function getAssetProperties(address _asset, address _assetsRegistry)
        internal
        view
        returns (bytes memory assetProperties)
    {
        // get the calldata for calling `assetProperties(_asset)`
        bytes memory calld = abi.encodeCall(IAssetsRegistry.assetProperties, (_asset));

        assembly ("memory-safe") {
            // get the free memory pointer
            assetProperties := mload(FREE_MEM_PTR)

            // call `assetProperties` with the encoded calldata, ignoring the success value
            // and the result from the call, which will be read from the returndata below
            pop(staticcall(gas(), _assetsRegistry, add(calld, ONE_WORD), mload(calld), 0, 0))

            // get the size of the returned data
            let returnLen := returndatasize()

            // copy the whole result from the `assetProperties` call to memory
            returndatacopy(assetProperties, 0, returnLen)

            // reset the free memory pointer to after the assetProperties that were
            // just copied from returdata to memory
            mstore(FREE_MEM_PTR, add(assetProperties, returnLen))
        }
    }

    /// @notice generates the name and symbol for an option and adds them to the immutable args
    /// in memory starting at the given pointer
    /// @param assetProperties pointer to the underlying asset properties in memory
    /// @param immutableArgsData pointer to the start of the clone immutable args data in memory
    /// @param packedArgsStart pointer to the start of the other args already packed in memory
    function addNameAndSymbolToImmutableArgs(
        bytes memory assetProperties,
        bytes memory immutableArgsData,
        uint256 packedArgsStart
    )
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

        // new scope block to avoid stack too deep errors with viaIR turned off
        {
            address underlyingAsset;
            uint88 expiryTime;
            bool isCall;
            uint256 strikePrice;

            assembly ("memory-safe") {
                /* packed args memory layout, starting at packedArgsStart:
                0x00: OPTIONS_DECIMALS |   (uint8 == 1 byte)
                0x01: underlyingAsset  | (address == 20 bytes)
                0x15: strikeAsset      | (address == 20 bytes)
                0x29: oracle           | (address == 20 bytes)
                0x3d: expiryTime       |  (uint88 == 11 bytes)
                0x48: isCall           |    (bool == 1 byte)
                0x49: strikePrice      | (uint256 == 32 bytes)
                0x69: controller       | (address == 20 bytes)
                */

                // get the individual values from the packed args in memory
                underlyingAsset := shr(96, mload(add(packedArgsStart, 0x01)))

                expiryTime := shr(168, mload(add(packedArgsStart, 0x3d)))

                isCall := shr(248, mload(add(packedArgsStart, 0x48)))

                strikePrice := mload(add(packedArgsStart, 0x49))

                // The underlying asset symbol is the second property in assetProperties,
                // thus, it's located at assetProperties + ONE_WORD
                underlying := add(assetProperties, mload(add(assetProperties, ONE_WORD)))
            }

            displayStrikePrice = displayedStrikePrice(strikePrice);

            // get option type string
            (typeSymbol, typeFull) = getOptionType(isCall);

            // get the individual date values so we can convert the expiry to a readable string
            (uint256 year, uint256 month, uint256 day) = DateTime.timestampToDate(expiryTime);

            // get option month string
            (monthSymbol, monthFull) = getMonth(month);

            // get the day and year strings
            dayStr = getDayStr(day);
            yearStr = LibString.toString(year);
        }

        // for the current free memory pointer, after the packed args and all the strings
        // generated and automatically allocated in the steps above
        uint256 newFreeMemPtr;

        assembly ("memory-safe") {
            // save the current free memory pointer so that it can be restored later after
            // all the free memory pointer manipulations are done
            newFreeMemPtr := mload(FREE_MEM_PTR)

            // copy the first 32 bytes of the packed args which might get partially overwritten
            // in the automatic generation and allocation of the symbol string below
            mstore(newFreeMemPtr, mload(packedArgsStart))

            // set the free memory pointer to 128 bytes after the immutable args
            // start so that the symbol string gets stored in that space
            mstore(FREE_MEM_PTR, add(immutableArgsData, IMMUTABLE_STRING_LENGTH))
        }

        // generate, allocate and store the symbol string right before the packed args
        string memory metadata =
            string.concat("ROLLA-", underlying, "-", dayStr, monthSymbol, yearStr, "-", displayStrikePrice, "-", typeSymbol);

        normalizeStringImmutableArg(metadata);

        assembly ("memory-safe") {
            // recover the initial 32 bytes of the packed args that may have
            // been partially overwritten
            mstore(packedArgsStart, mload(newFreeMemPtr))

            // update the new free memory pointer to after the 32 bytes of the
            // packed args that were copied earlier for the recovery above
            newFreeMemPtr := add(newFreeMemPtr, ONE_WORD)

            // clear the 32 bytes where the symbol string length was stored
            mstore(add(immutableArgsData, IMMUTABLE_STRING_LENGTH), 0)

            // set the free memory pointer to the start of the immutable args
            // so that the name string gets stored in that space
            mstore(FREE_MEM_PTR, immutableArgsData)
        }

        // generate, allocate and store the name string right before the symbol string
        metadata = string.concat(
            "ROLLA ", underlying, " ", dayStr, "-", monthFull, "-", yearStr, " ", displayStrikePrice, " ", typeFull
        );

        normalizeStringImmutableArg(metadata);

        assembly ("memory-safe") {
            // store the total QToken immutable arguments size at its pointer,
            // overriding the previous name string length that was stored there
            mstore(immutableArgsData, IMMUTABLE_ARGS_LENGTH)

            // restore the free memory pointer
            mstore(FREE_MEM_PTR, newFreeMemPtr)
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
            if gt(len, MAX_STRING_LENGTH) {
                mstore(DataSizeLimitExceeded_error_sig_ptr, DataSizeLimitExceeded_error_signature)
                mstore(DataSizeLimitExceeded_error_datasize_ptr, len)
                revert(DataSizeLimitExceeded_error_sig_ptr, DataSizeLimitExceeded_error_length)
            }

            // store the original length of the string in the last byte of the output
            // location in memory, i.e. the 128th byte
            mstore(
                add(s, IMMUTABLE_STRING_LENGTH), xor(mload(add(s, IMMUTABLE_STRING_LENGTH)), shl(ONE_BYTE_OFFSET, len))
            )
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
            dayStr := mload(FREE_MEM_PTR)
            mstore(FREE_MEM_PTR, add(dayStr, 0x22))
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
