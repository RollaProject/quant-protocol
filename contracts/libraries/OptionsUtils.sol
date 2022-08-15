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

    // abi.encodeWithSignature("DataSizeLimitExceeded(uint256)");
    uint256 internal constant DataSizeLimitExceeded_error_signature =
        0x5307a82000000000000000000000000000000000000000000000000000000000;

    uint256 internal constant DataSizeLimitExceeded_error_sig_ptr = 0x0;

    uint256 internal constant DataSizeLimitExceeded_error_datasize_ptr = 0x4;

    uint256 internal constant DataSizeLimitExceeded_error_length = 0x24; // 4 + 32 == 36

    /// @notice Checks if the given option parameters are valid for creation in the Quant Protocol
    /// @param _oracleRegistry oracle registry to validate the passed _oracle against
    /// @param _underlyingAsset asset that the option is for
    /// @param _assetsRegistry address of the AssetsRegistry contract
    /// @param _oracle price oracle for the option underlying
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _strikePrice strike price with as many decimals in the strike asset
    function validateOptionParameters(
        address _oracleRegistry,
        address _underlyingAsset,
        address _assetsRegistry,
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

        require(isInAssetsRegistry(_underlyingAsset, _assetsRegistry), "underlying not in the registry");
    }

    /// @notice Checks if a given asset is in the AssetsRegistry
    /// @param _asset address of the asset to check
    /// @param _assetsRegistry address of the AssetsRegistry contract
    /// @return isRegistered whether the asset is in the configured registry
    function isInAssetsRegistry(address _asset, address _assetsRegistry) internal view returns (bool isRegistered) {
        (,,, isRegistered) = IAssetsRegistry(_assetsRegistry).assetProperties(_asset);
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

    /// @notice get the ERC20 token symbol from the AssetsRegistry
    /// @dev the asset is assumed to be in the AssetsRegistry since QTokens
    /// must be created through the OptionsFactory, which performs that check
    /// @param _asset address of the asset in the AssetsRegistry
    /// @param _assetsRegistry address of the AssetsRegistry contract
    /// @return assetSymbol_ string stored as the ERC20 token symbol
    function assetSymbol(address _asset, address _assetsRegistry) internal view returns (string memory assetSymbol_) {
        (, assetSymbol_,,) = IAssetsRegistry(_assetsRegistry).assetProperties(_asset);
    }

    /// @notice generates the name and symbol for an option
    /// @param _underlyingAsset asset that the option references
    /// @param _assetsRegistry address of the AssetsRegistry
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @return name and symbol for the QToken
    function getQTokenMetadata(
        address _underlyingAsset,
        address _assetsRegistry,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice
    )
        internal
        view
        returns (string memory name, string memory symbol)
    {
        string memory underlying = assetSymbol(_underlyingAsset, _assetsRegistry);

        string memory displayStrikePrice = displayedStrikePrice(_strikePrice);

        // convert the expiry to a readable string
        (uint256 year, uint256 month, uint256 day) = DateTime.timestampToDate(_expiryTime);

        // get option type string
        (string memory typeSymbol, string memory typeFull) = getOptionType(_isCall);

        // get option month string
        (string memory monthSymbol, string memory monthFull) = getMonth(month);

        // get the day and year strings
        string memory dayStr = getDayStr(day);
        string memory yearStr = LibString.toString(year);

        // concatenated name and symbol strings
        name = string.concat(
            "ROLLA", " ", underlying, " ", dayStr, "-", monthFull, "-", yearStr, " ", displayStrikePrice, " ", typeFull
        );

        normalizeStringImmutableArg(name);

        symbol = string.concat(
            "ROLLA", "-", underlying, "-", dayStr, monthSymbol, yearStr, "-", displayStrikePrice, "-", typeSymbol
        );

        normalizeStringImmutableArg(symbol);
    }

    /// @notice Gets the encoded immutable arguments for creating a QToken clone
    /// using the ClonesWithImmutableArgs library
    /// @param _optionsDecimals the amount of decimals in QToken amounts
    /// @param _underlyingAsset address of the option underlying asset
    /// @param _strikeAsset asset that the option is settled on
    /// @param _assetsRegistry address of the AssetsRegistry contract
    /// @param _oracle price oracle for the option's underlying asset
    /// @param _expiryTime option expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @param _controller address of the Quant Controller contract
    /// @return data encoded data for creating a QToken clone
    function getQTokenImmutableArgs(
        uint8 _optionsDecimals,
        address _underlyingAsset,
        address _strikeAsset,
        address _assetsRegistry,
        address _oracle,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice,
        address _controller
    )
        internal
        view
        returns (bytes memory data)
    {
        (string memory name, string memory symbol) =
            getQTokenMetadata(_underlyingAsset, _assetsRegistry, _expiryTime, _isCall, _strikePrice);

        data = abi.encodePacked(
            name,
            symbol,
            _optionsDecimals,
            _underlyingAsset,
            _strikeAsset,
            _oracle,
            _expiryTime,
            _isCall,
            _strikePrice,
            _controller
        );
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

            // update the free memory pointer, padding the new string length to 32 bytes
            mstore(0x40, add(s, and(add(add(0x80, 0x20), 0x1f), not(0x1f))))

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
