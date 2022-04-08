// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../pricing/PriceRegistry.sol";
import "../interfaces/IQToken.sol";
import "../libraries/OptionsUtils.sol";
import "../libraries/QuantMath.sol";
import "./QTokenStringUtils.sol";

/// @title Token that represents a user's long position
/// @author Rolla
/// @notice Can be used by owners to exercise their options
/// @dev Every option long position is an ERC20 token: https://eips.ethereum.org/EIPS/eip-20
contract QToken is ERC20Permit, QTokenStringUtils, IQToken, Ownable {
    using QuantMath for uint256;

    /// @inheritdoc IQToken
    address public override underlyingAsset;

    /// @inheritdoc IQToken
    address public override strikeAsset;

    /// @inheritdoc IQToken
    address public override oracle;

    address public priceRegistry;

    /// @inheritdoc IQToken
    uint256 public override strikePrice;

    /// @inheritdoc IQToken
    uint256 public override expiryTime;

    /// @inheritdoc IQToken
    bool public override isCall;

    /// @notice Configures the parameters of a new option token
    /// @param _underlyingAsset asset that the option references
    /// @param _strikeAsset asset that the strike is denominated in
    /// @param _oracle price oracle for the underlying
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    constructor(
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        address _priceRegistry,
        address _assetsRegistry,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    )
        ERC20(
            _qTokenName(
                _underlyingAsset,
                _strikeAsset,
                _assetsRegistry,
                _strikePrice,
                _expiryTime,
                _isCall
            ),
            _qTokenSymbol(
                _underlyingAsset,
                _strikeAsset,
                _assetsRegistry,
                _strikePrice,
                _expiryTime,
                _isCall
            )
        )
        ERC20Permit(
            _qTokenName(
                _underlyingAsset,
                _strikeAsset,
                _assetsRegistry,
                _strikePrice,
                _expiryTime,
                _isCall
            )
        )
    {
        require(
            _underlyingAsset != address(0),
            "QToken: invalid underlying asset address"
        );
        require(
            _strikeAsset != address(0),
            "QToken: invalid strike asset address"
        );
        require(_oracle != address(0), "QToken: invalid oracle address");
        require(
            _priceRegistry != address(0),
            "QToken: invalid price registry address"
        );

        underlyingAsset = _underlyingAsset;
        strikeAsset = _strikeAsset;
        oracle = _oracle;
        priceRegistry = _priceRegistry;
        strikePrice = _strikePrice;
        expiryTime = _expiryTime;
        isCall = _isCall;
    }

    /// @inheritdoc IQToken
    function mint(address account, uint256 amount) external override onlyOwner {
        _mint(account, amount);
        emit QTokenMinted(account, amount);
    }

    /// @inheritdoc IQToken
    function burn(address account, uint256 amount) external override onlyOwner {
        _burn(account, amount);
        emit QTokenBurned(account, amount);
    }

    /// @inheritdoc IQToken
    function getOptionPriceStatus()
        external
        view
        override
        returns (PriceStatus)
    {
        if (block.timestamp > expiryTime) {
            if (
                PriceRegistry(priceRegistry).hasSettlementPrice(
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

    /// @inheritdoc IQToken
    function getQTokenInfo()
        external
        view
        override
        returns (QTokenInfo memory)
    {
        return OptionsUtils.getQTokenInfo(address(this));
    }
}
