// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@quant-finance/solidity-datetime/contracts/DateTime.sol";
import "./AssetsRegistry.sol";
import "../QuantConfig.sol";
import "../pricing/PriceRegistry.sol";

/// @dev Current pricing status of option. Only SETTLED options can be exercised
enum PriceStatus {ACTIVE, AWAITING_SETTLEMENT_PRICE, SETTLED}

/// @title Token that represents a user's long position
/// @author Quant Finance
/// @notice Can be used by owners to exercise their options
/// @dev Every option long position is an ERC20 token: https://eips.ethereum.org/EIPS/eip-20
contract QToken is ERC20 {
    using SafeMath for uint256;

    /// @dev Address of system config.
    QuantConfig public quantConfig;

    /// @dev Address of the underlying asset. WETH for ethereum options.
    address public underlyingAsset;

    /// @dev Address of the strike asset. Quant Web options always use USDC.
    address public strikeAsset;

    /// @dev Address of the oracle to be used with this option
    address public oracle;

    /// @dev The strike price for the token with the strike asset precision.
    uint256 public strikePrice;

    /// @dev UNIX time for the expiry of the option
    uint256 public expiryTime;

    /// @dev True if the option is a CALL. False if the option is a PUT.
    bool public isCall;

    uint256 private constant _STRIKE_PRICE_SCALE = 1e6;
    uint256 private constant _STRIKE_PRICE_DIGITS = 6;

    /// @notice event emitted when QTokens are minted
    /// @param account account the QToken was minted to
    /// @param amount the amount of QToken minted
    event QTokenMinted(address indexed account, uint256 amount);

    /// @notice event emitted when QTokens are burned
    /// @param account account the QToken was burned from
    /// @param amount the amount of QToken burned
    event QTokenBurned(address indexed account, uint256 amount);

    /// @notice Configures the parameters of a new option token
    /// @param _quantConfig the address of the Quant system configuration contract
    /// @param _underlyingAsset asset that the option references
    /// @param _strikeAsset asset that the strike is denominated in
    /// @param _oracle price oracle for the underlying
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    constructor(
        address _quantConfig,
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    )
        ERC20(
            _qTokenName(
                _quantConfig,
                _underlyingAsset,
                _strikeAsset,
                _strikePrice,
                _expiryTime,
                _isCall
            ),
            _qTokenSymbol(
                _quantConfig,
                _underlyingAsset,
                _strikeAsset,
                _strikePrice,
                _expiryTime,
                _isCall
            )
        )
    {
        quantConfig = QuantConfig(_quantConfig);
        underlyingAsset = _underlyingAsset;
        strikeAsset = _strikeAsset;
        oracle = _oracle;
        strikePrice = _strikePrice;
        expiryTime = _expiryTime;
        isCall = _isCall;
    }

    /// @notice mint option token for an account
    /// @param account account to mint token to
    /// @param amount amount to mint
    function mint(address account, uint256 amount) external {
        require(
            quantConfig.hasRole(
                quantConfig.OPTIONS_CONTROLLER_ROLE(),
                msg.sender
            ),
            "QToken: Only the Controller can mint QTokens"
        );
        _mint(account, amount);
        emit QTokenMinted(account, amount);
    }

    /// @notice burn option token from an account.
    /// @param account account to burn token from
    /// @param amount amount to burn
    function burn(address account, uint256 amount) external {
        require(
            quantConfig.hasRole(
                quantConfig.OPTIONS_CONTROLLER_ROLE(),
                msg.sender
            ),
            "QToken: Only the OptionsFactory can burn QTokens"
        );
        _burn(account, amount);
        emit QTokenBurned(account, amount);
    }

    /// @notice get the ERC20 token symbol from the AssetsRegistry
    /// @dev the asset is assumed to be in the AssetsRegistry since QTokens
    /// must be created through the OptionsFactory, which performs that check
    /// @param _quantConfig address of the Quant system configuration contract
    /// @param _asset address of the asset in the AssetsRegistry
    /// @return symbol string stored as the ERC20 token symbol
    function _assetSymbol(address _quantConfig, address _asset)
        internal
        view
        returns (string memory symbol)
    {
        (, symbol, ) = AssetsRegistry(
            QuantConfig(_quantConfig).assetsRegistry()
        )
            .assetProperties(_asset);
    }

    /// @notice generates the name for an option
    /// @param _quantConfig address of the Quant system configuration contract
    /// @param _underlyingAsset asset that the option references
    /// @param _strikeAsset asset that the strike is denominated in
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @return tokenName name string for the QToken
    function _qTokenName(
        address _quantConfig,
        address _underlyingAsset,
        address _strikeAsset,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    ) internal view returns (string memory tokenName) {
        string memory underlying = _assetSymbol(_quantConfig, _underlyingAsset);
        string memory strike = _assetSymbol(_quantConfig, _strikeAsset);
        string memory displayStrikePrice = _displayedStrikePrice(_strikePrice);

        // convert the expiry to a readable string
        (uint256 year, uint256 month, uint256 day) =
            DateTime.timestampToDate(_expiryTime);

        // get option type string
        (, string memory typeFull) = _getOptionType(_isCall);

        // get option month string
        (, string memory monthFull) = _getMonth(month);

        /// concatenated name string
        tokenName = string(
            abi.encodePacked(
                "QUANT",
                " ",
                underlying,
                "-",
                strike,
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
    /// @param _quantConfig address of the Quant system configuration contract
    /// @param _strikeAsset asset that the strike is denominated in
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @return tokenSymbol symbol string for the QToken
    function _qTokenSymbol(
        address _quantConfig,
        address _underlyingAsset,
        address _strikeAsset,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    ) internal view returns (string memory tokenSymbol) {
        string memory underlying = _assetSymbol(_quantConfig, _underlyingAsset);
        string memory strike = _assetSymbol(_quantConfig, _strikeAsset);
        string memory displayStrikePrice = _displayedStrikePrice(_strikePrice);

        // convert the expiry to a readable string
        (uint256 year, uint256 month, uint256 day) =
            DateTime.timestampToDate(_expiryTime);

        // get option type string
        (string memory typeSymbol, ) = _getOptionType(_isCall);

        // get option month string
        (string memory monthSymbol, ) = _getMonth(month);

        /// concatenated symbol string
        tokenSymbol = string(
            abi.encodePacked(
                "QUANT",
                "-",
                underlying,
                "-",
                strike,
                "-",
                _uintToChars(day),
                monthSymbol,
                _uintToChars(year),
                "-",
                displayStrikePrice,
                "-",
                typeSymbol
            )
        );
    }

    /// @dev get the string representation of the option type
    /// @return a 1 character representation of the option type
    /// @return a full length string of the option type
    function _getOptionType(bool _isCall)
        internal
        pure
        returns (string memory, string memory)
    {
        return _isCall ? ("C", "Call") : ("P", "Put");
    }

    /// @dev convert the option strike price scaled to a human readable value
    /// @param _strikePrice the option strike price scaled by 1e8
    /// @return strike price string
    function _displayedStrikePrice(uint256 _strikePrice)
        internal
        pure
        returns (string memory)
    {
        uint256 remainder = _strikePrice.mod(_STRIKE_PRICE_SCALE);
        uint256 quotient = _strikePrice.div(_STRIKE_PRICE_SCALE);
        string memory quotientStr = Strings.toString(quotient);

        if (remainder == 0) {
            return quotientStr;
        }

        uint256 trailingZeroes;
        while (remainder.mod(10) == 0) {
            remainder /= 10;
            trailingZeroes += 1;
        }

        // pad the number with "1 + starting zeroes"
        remainder += 10**(_STRIKE_PRICE_DIGITS - trailingZeroes);

        string memory tmp = Strings.toString(remainder);
        tmp = _slice(tmp, 1, 1 + _STRIKE_PRICE_DIGITS - trailingZeroes);

        return string(abi.encodePacked(quotientStr, ".", tmp));
    }

    /// @dev get the representation of a number using 2 characters, adding a leading 0 if it's one digit,
    /// and two trailing digits if it's a 3 digit number
    /// @return 2 characters that correspond to a number
    function _uintToChars(uint256 _number)
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
    function _slice(
        string memory _s,
        uint256 _start,
        uint256 _end
    ) internal pure returns (string memory) {
        bytes memory slice = new bytes(_end - _start);
        for (uint256 i = 0; i < _end - _start; i++) {
            slice[i] = bytes(_s)[_start + 1];
        }

        return string(slice);
    }

    /// @dev get the string representations of a month
    /// @return a 3 character representation
    /// @return a full length string representation
    function _getMonth(uint256 _month)
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
        } else {
            return ("DEC", "December");
        }
    }

    /// @notice Get the price status of the option.
    /// @return the price status of the option. option is either active, awaiting settlement price or settled
    function getOptionPriceStatus() external view returns (PriceStatus) {
        if (block.timestamp > expiryTime) {
            PriceRegistry priceRegistry =
                PriceRegistry(quantConfig.priceRegistry());
            if (
                priceRegistry.hasSettlementPrice(
                    oracle,
                    underlyingAsset,
                    expiryTime
                )
            ) {
                return PriceStatus.SETTLED;
            }
            return PriceStatus.AWAITING_SETTLEMENT_PRICE;
        } else {
            return PriceStatus.ACTIVE;
        }
    }
}
