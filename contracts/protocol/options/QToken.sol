// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../QuantConfig.sol";

contract QToken is ERC20 {
    /**
     * @dev Address of system config.
     */
    QuantConfig public quantConfig;

    /**
     * @dev Address of the underlying asset. WETH for ethereum options.
     */
    address public underlyingAsset;

    /**
     * @dev Address of the strike asset. Quant Web options always use USDC.
     */
    address public strikeAsset;

    /**
     * @dev The strike price for the token with the strike asset precision.
     */
    uint256 public strikePrice;

    /**
     * @dev UNIX time for the expiry of the option
     */
    uint256 public expiryTime;

    /**
     * @dev True if the option is a CALL. False if the option is a PUT.
     */
    bool public isCall;

    /**
     * @dev Only allow the OptionsFactory or governance/admin to call a certain function
     */
    modifier onlyOptionsController(string memory _message) {
        require(
            quantConfig.hasRole(
                quantConfig.OPTIONS_CONTROLLER_ROLE(),
                msg.sender
            ),
            _message
        );
        _;
    }

    /// @notice Configures the parameters of a new option token
    /// @param _quantConfig the address of the Quant system configuration contract
    /// @param _underlyingAsset asset that the option references
    /// @param _strikeAsset asset that the strike is denominated in
    /// @param _strikePrice strike price with 18 decimals
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    constructor(
        address _quantConfig,
        address _underlyingAsset,
        address _strikeAsset,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    ) ERC20("tokenName", "tokenSymbol") {
        quantConfig = QuantConfig(_quantConfig);
        underlyingAsset = _underlyingAsset;
        strikeAsset = _strikeAsset;
        strikePrice = _strikePrice;
        expiryTime = _expiryTime;
        isCall = _isCall;
    }

    /**
     * @notice mint option token for an account
     * @dev Controller only method where access control is taken care of by _beforeTokenTransfer hook
     * @param account account to mint token to
     * @param amount amount to mint
     */
    function mint(address account, uint256 amount)
        external
        onlyOptionsController(
            "QToken: Only the OptionsFactory can mint QTokens"
        )
    {
        _mint(account, amount);
    }

    /**
     * @notice burn option token from an account.
     * @dev Controller only method where access control is taken care of by _beforeTokenTransfer hook
     * @param account account to burn token from
     * @param amount amount to burn
     */
    function burn(address account, uint256 amount)
        external
        onlyOptionsController(
            "QToken: Only the OptionsFactory can burn QTokens"
        )
    {
        _burn(account, amount);
    }
}
