// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@quant-finance/solidity-datetime/contracts/DateTime.sol";
import "../interfaces/IAssetsRegistry.sol";

abstract contract QTokenStringUtils {
    /// @notice get the ERC20 token symbol and decimals from the AssetsRegistry
    /// @dev the asset is assumed to be in the AssetsRegistry since QTokens
    /// must be created through the OptionsFactory, which performs that check
    /// @param _asset address of the asset in the AssetsRegistry
    /// @param _assetsRegistry address of the AssetsRegistry contract
    /// @return assetSymbol string stored as the ERC20 token symbol
    /// @return assetDecimals uint8 stored as the ERC20 token decimals
    function _assetSymbolAndDecimals(address _asset, address _assetsRegistry)
        internal
        view
        virtual
        returns (string memory assetSymbol, uint8 assetDecimals)
    {
        (, assetSymbol, assetDecimals) = IAssetsRegistry(_assetsRegistry)
            .assetProperties(_asset);
        require(
            bytes(assetSymbol).length > 0,
            "QTokenStringUtils: asset is not in the registry"
        );
    }

    /// @notice generates the name for an option
    /// @param _underlyingAsset asset that the option references
    /// @param _strikeAsset asset that the option is settled on
    /// @param _assetsRegistry address of the AssetsRegistry
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @return tokenName name string for the QToken
    function _qTokenName(
        address _underlyingAsset,
        address _strikeAsset,
        address _assetsRegistry,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    ) internal view virtual returns (string memory tokenName) {
        (string memory underlying, ) = _assetSymbolAndDecimals(
            _underlyingAsset,
            _assetsRegistry
        );
        (, uint8 strikePriceDecimals) = _assetSymbolAndDecimals(
            _strikeAsset,
            _assetsRegistry
        );
        string memory displayStrikePrice = _displayedStrikePrice(
            _strikePrice,
            strikePriceDecimals
        );

        // convert the expiry to a readable string
        (uint256 year, uint256 month, uint256 day) = DateTime.timestampToDate(
            _expiryTime
        );

        // get option type string
        (, string memory typeFull) = _getOptionType(_isCall);

        // get option month string
        (, string memory monthFull) = _getMonth(month);

        /// concatenated name string
        tokenName = string(
            abi.encodePacked(
                "ROLLA",
                " ",
                underlying,
                " ",
                _uintToChars(day),
                "-",
                monthFull,
                "-",
                Strings.toString(year),
                " ",
                displayStrikePrice,
                " ",
                typeFull
            )
        );
    }

    /// @notice generates the symbol for an option
    /// @param _underlyingAsset asset that the option references
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @return tokenSymbol symbol string for the QToken
    function _qTokenSymbol(
        address _underlyingAsset,
        address _strikeAsset,
        address _assetsRegistry,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    ) internal view virtual returns (string memory tokenSymbol) {
        (string memory underlying, ) = _assetSymbolAndDecimals(
            _underlyingAsset,
            _assetsRegistry
        );
        (, uint8 strikePriceDecimals) = _assetSymbolAndDecimals(
            _strikeAsset,
            _assetsRegistry
        );
        string memory displayStrikePrice = _displayedStrikePrice(
            _strikePrice,
            strikePriceDecimals
        );

        // convert the expiry to a readable string
        (uint256 year, uint256 month, uint256 day) = DateTime.timestampToDate(
            _expiryTime
        );

        // get option type string
        (string memory typeSymbol, ) = _getOptionType(_isCall);

        // get option month string
        (string memory monthSymbol, ) = _getMonth(month);

        /// concatenated symbol string
        tokenSymbol = string(
            abi.encodePacked(
                "ROLLA",
                "-",
                underlying,
                "-",
                _uintToChars(day),
                monthSymbol,
                Strings.toString(year),
                "-",
                displayStrikePrice,
                "-",
                typeSymbol
            )
        );
    }

    /// @dev convert the option strike price scaled to a human readable value
    /// @param _strikePrice the option strike price scaled by 1e20
    /// @return strike price string
    function _displayedStrikePrice(
        uint256 _strikePrice,
        uint8 _strikePriceDecimals
    ) internal view virtual returns (string memory) {
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
        tmp = _slice(tmp, 1, (1 + _strikePriceDecimals) - trailingZeroes);

        return string(abi.encodePacked(quotientStr, ".", tmp));
    }

    /// @dev get the string representation of the option type
    /// @return a 1 character representation of the option type
    /// @return a full length string of the option type
    function _getOptionType(bool _isCall)
        internal
        pure
        virtual
        returns (string memory, string memory)
    {
        return _isCall ? ("C", "Call") : ("P", "Put");
    }

    /// @dev get the representation of a number using 2 characters, adding a leading 0 if it's one digit,
    /// and two trailing digits if it's a 3 digit number
    /// @return 2 characters that correspond to a number
    function _uintToChars(uint256 _number)
        internal
        pure
        virtual
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
    function _slice(
        string memory _s,
        uint256 _start,
        uint256 _end
    ) internal pure virtual returns (string memory) {
        uint256 range = _end - _start;
        bytes memory slice = new bytes(range);
        for (uint256 i = 0; i < range; ) {
            slice[i] = bytes(_s)[_start + i];
            unchecked {
                ++i;
            }
        }

        return string(slice);
    }

    /// @dev get the string representations of a month
    /// @return a 3 character representation
    /// @return a full length string representation
    function _getMonth(uint256 _month)
        internal
        pure
        virtual
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
            revert("QTokenStringUtils: invalid month");
        }
    }
}
