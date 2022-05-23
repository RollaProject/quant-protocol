// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.14;

import "@rolla-finance/clones-with-immutable-args/ClonesWithImmutableArgs.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@quant-finance/solidity-datetime/contracts/DateTime.sol";
import "../options/QToken.sol";
import "../interfaces/ICollateralToken.sol";
import "../interfaces/IOracleRegistry.sol";
import "../interfaces/IProviderOracleManager.sol";
import "../interfaces/IQToken.sol";
import "../interfaces/IAssetsRegistry.sol";

struct QTokenMetadata {
    uint256[] name;
    uint256[] symbol;
}

/// @title Options utilities for Quant's QToken and CollateralToken
/// @author Rolla
library OptionsUtils {
    /// @notice salt to be used with CREATE2 when creating new options
    /// @dev constant salt because options will only be deployed with the same parameters once
    bytes32 public constant SALT = bytes32("ROLLA.FINANCE");

    /// @notice Splits a dinamically-sized byte array into an array of unsigned integers
    /// in which each element represents a 32 byte chunk of the original data
    /// @dev Uses the identity precompile to copy data from memory to memory
    /// @param _data the original bytes to be converted to an array of uint256 values
    /// @return result an array of uint256 values that represent 32 byte chunks of the original data,
    /// in which the last byte represent the length of the original data
    function bytesToUint256Array(bytes memory _data)
        internal
        view
        returns (uint256[] memory result)
    {
        // The data will be converted into an array of uint256 with a total length of 128 bytes,
        // which is enough to safely cover QToken names and symbols with a strike price up to the
        // max uint256 and an ERC20 underlying token symbol with 20+ characters.
        // The last byte stores the length of the data, and the first 127 bytes store the actual data.
        result = new uint256[](4);

        // annotate the assembly block below as memory-safe since the input data length is checked before
        // being copied to the uint256 array with a maximum length of 127 bytes, and so that the compiler
        // can move local variables from stack to memory to avoid stack-too-deep errors and perform
        // additional memory optimizations
        assembly ("memory-safe") {
            // get the length of the input data
            let len := mload(_data)

            // store the length of the data in the last byte of the output location in memory,
            // i.e. the 128th byte in the uint256 array
            mstore(add(result, 0x80), shl(0xf8, len))

            // can end execution with the INVALID opcode due to either the input data being
            // too large or the staticcall to the identity precompile failing
            if or(
                gt(len, 0x7f), // the data passed in can't be larger than 127 bytes
                iszero(
                    staticcall(
                        gas(), // forward all the gas available to the call
                        0x04, // the address of the identity (datacopy) precompiled contract
                        add(_data, 0x20), // position of the input bytes in memory, after the 32 bytes for the length
                        len, // size of the input bytes in memory
                        add(result, 0x20), // position of the output area in memory, after the 32 bytes for the length
                        len // size of the output in memory, same as the input
                    )
                )
            ) {
                invalid()
            }
        }
    }

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
    ) internal view {
        require(
            _expiryTime > block.timestamp,
            "OptionsFactory: given expiry time is in the past"
        );

        require(
            IProviderOracleManager(_oracle).isValidOption(
                _underlyingAsset,
                _expiryTime,
                _strikePrice
            ),
            "OptionsFactory: Oracle doesn't support the given option"
        );

        require(
            IOracleRegistry(_oracleRegistry).isOracleActive(_oracle),
            "OptionsFactory: Oracle is not active in the OracleRegistry"
        );

        require(_strikePrice > 0, "strike can't be 0");

        require(
            isInAssetsRegistry(_underlyingAsset, _assetsRegistry),
            "underlying not in the registry"
        );
    }

    /// @notice Checks if a given asset is in the AssetsRegistry
    /// @param _asset address of the asset to check
    /// @param _assetsRegistry address of the AssetsRegistry contract
    /// @return isRegistered whether the asset is in the configured registry
    function isInAssetsRegistry(address _asset, address _assetsRegistry)
        internal
        view
        returns (bool isRegistered)
    {
        (, , , isRegistered) = IAssetsRegistry(_assetsRegistry).assetProperties(
            _asset
        );
    }

    /// @notice Gets the amount of decimals for an option exercise payout
    /// @param _strikeAssetDecimals decimals of the strike asset
    /// @param _qToken address of the option's QToken contract
    /// @param _assetsRegistry address of the AssetsRegistry contract
    /// @return payoutDecimals amount of decimals for the option exercise payout
    function getPayoutDecimals(
        uint8 _strikeAssetDecimals,
        IQToken _qToken,
        address _assetsRegistry
    ) internal view returns (uint8 payoutDecimals) {
        if (_qToken.isCall()) {
            (, , payoutDecimals, ) = IAssetsRegistry(_assetsRegistry)
                .assetProperties(_qToken.underlyingAsset());
        } else {
            payoutDecimals = _strikeAssetDecimals;
        }
    }

    /// @notice get the ERC20 token symbol and decimals from the AssetsRegistry
    /// @dev the asset is assumed to be in the AssetsRegistry since QTokens
    /// must be created through the OptionsFactory, which performs that check
    /// @param _asset address of the asset in the AssetsRegistry
    /// @param _assetsRegistry address of the AssetsRegistry contract
    /// @return assetSymbol string stored as the ERC20 token symbol
    /// @return assetDecimals uint8 stored as the ERC20 token decimals
    function assetSymbolAndDecimals(address _asset, address _assetsRegistry)
        internal
        view
        returns (string memory assetSymbol, uint8 assetDecimals)
    {
        bool isRegistered;
        (, assetSymbol, assetDecimals, isRegistered) = IAssetsRegistry(
            _assetsRegistry
        ).assetProperties(_asset);

        require(isRegistered, "OptionsUtils: asset is not in the registry");
    }

    /// @notice generates the name for an option
    /// @param _underlyingAsset asset that the option references
    /// @param _strikeAsset asset that the option is settled on
    /// @param _assetsRegistry address of the AssetsRegistry
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @return qTokenMetadata name and symbol for the QToken
    function getQTokenMetadata(
        address _underlyingAsset,
        address _strikeAsset,
        address _assetsRegistry,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice
    ) internal view returns (QTokenMetadata memory qTokenMetadata) {
        (string memory underlying, ) = assetSymbolAndDecimals(
            _underlyingAsset,
            _assetsRegistry
        );
        (, uint8 strikePriceDecimals) = assetSymbolAndDecimals(
            _strikeAsset,
            _assetsRegistry
        );
        string memory displayStrikePrice = displayedStrikePrice(
            _strikePrice,
            strikePriceDecimals
        );

        // convert the expiry to a readable string
        (uint256 year, uint256 month, uint256 day) = DateTime.timestampToDate(
            _expiryTime
        );

        // get option type string
        (string memory typeSymbol, string memory typeFull) = getOptionType(
            _isCall
        );

        // get option month string
        (string memory monthSymbol, string memory monthFull) = getMonth(month);

        /// concatenated name and symbol strings
        qTokenMetadata = QTokenMetadata({
            name: bytesToUint256Array(
                abi.encodePacked(
                    "ROLLA",
                    " ",
                    underlying,
                    " ",
                    uintToChars(day),
                    "-",
                    monthFull,
                    "-",
                    Strings.toString(year),
                    " ",
                    displayStrikePrice,
                    " ",
                    typeFull
                )
            ),
            symbol: bytesToUint256Array(
                abi.encodePacked(
                    "ROLLA",
                    "-",
                    underlying,
                    "-",
                    uintToChars(day),
                    monthSymbol,
                    Strings.toString(year),
                    "-",
                    displayStrikePrice,
                    "-",
                    typeSymbol
                )
            )
        });
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
    ) internal view returns (bytes memory data) {
        QTokenMetadata memory qTokenMetadata = OptionsUtils.getQTokenMetadata(
            _underlyingAsset,
            _strikeAsset,
            _assetsRegistry,
            _expiryTime,
            _isCall,
            _strikePrice
        );

        data = abi.encodePacked(
            qTokenMetadata.name,
            qTokenMetadata.symbol,
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

    /// @dev convert the option strike price scaled to a human readable value
    /// @param _strikePrice the option strike price scaled by the strike asset decimals
    /// @param _strikePriceDecimals the amount of decimals in the strike asset
    /// @return strike price string
    function displayedStrikePrice(
        uint256 _strikePrice,
        uint8 _strikePriceDecimals
    ) internal pure returns (string memory) {
        uint256 strikePriceScale = 10**_strikePriceDecimals;
        uint256 remainder = _strikePrice % strikePriceScale;
        uint256 quotient = _strikePrice / strikePriceScale;
        string memory quotientStr = Strings.toString(quotient);

        if (remainder == 0) {
            return quotientStr;
        }

        uint256 trailingZeroes;
        while (remainder % 10 == 0) {
            remainder /= 10;
            trailingZeroes++;
        }

        // pad the number with "1 + starting zeroes"
        remainder += 10**(_strikePriceDecimals - trailingZeroes);

        string memory tmp = Strings.toString(remainder);
        tmp = slice(tmp, 1, (1 + _strikePriceDecimals) - trailingZeroes);

        return string(abi.encodePacked(quotientStr, ".", tmp));
    }

    /// @dev get the string representation of the option type
    /// @return a 1 character representation of the option type
    /// @return a full length string of the option type
    function getOptionType(bool _isCall)
        internal
        pure
        returns (string memory, string memory)
    {
        return _isCall ? ("C", "Call") : ("P", "Put");
    }

    /// @dev get the representation of a number using 2 characters, adding a leading 0 if it's one digit,
    /// and two trailing digits if it's a 3 digit number
    /// @return 2 characters that correspond to a number
    function uintToChars(uint256 _number)
        internal
        pure
        returns (string memory)
    {
        if (_number > 99) {
            _number %= 100;
        }

        string memory str = Strings.toString(_number);

        if (_number < 10) {
            return string(abi.encodePacked("0", str));
        }

        return str;
    }

    /// @dev cut a string into string[start:end]
    /// @param _s string to cut
    /// @param _start the starting index
    /// @param _end the ending index (not inclusive)
    /// @return the indexed string
    function slice(
        string memory _s,
        uint256 _start,
        uint256 _end
    ) internal pure returns (string memory) {
        uint256 range = _end - _start;
        bytes memory slice_ = new bytes(range);
        for (uint256 i = 0; i < range; ) {
            slice_[i] = bytes(_s)[_start + i];
            unchecked {
                ++i;
            }
        }

        return string(slice_);
    }

    /// @dev get the string representations of a month
    /// @return a 3 character representation
    /// @return a full length string representation
    function getMonth(uint256 _month)
        internal
        pure
        returns (string memory, string memory)
    {
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
