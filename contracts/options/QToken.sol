// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IPriceRegistry.sol";
import "../interfaces/IQToken.sol";
import "./QTokenStringUtils.sol";

/// @title Token that represents a user's long position
/// @author Rolla
/// @notice Can be used by owners to exercise their options
/// @dev Every option long position is an ERC20 token: https://eips.ethereum.org/EIPS/eip-20
contract QToken is ERC20Permit, QTokenStringUtils, IQToken, Ownable {
    /// @inheritdoc IQToken
    address public immutable override underlyingAsset;

    /// @inheritdoc IQToken
    address public immutable override strikeAsset;

    /// @inheritdoc IQToken
    address public immutable priceRegistry;

    /// @inheritdoc IQToken
    address public immutable override oracle;

    /// @inheritdoc IQToken
    uint88 public immutable override expiryTime;

    /// @inheritdoc IQToken
    bool public immutable override isCall;

    /// @inheritdoc IQToken
    uint256 public immutable override strikePrice;

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
        address _priceRegistry,
        address _assetsRegistry,
        address _oracle,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice
    )
        ERC20(
            _qTokenName(
                _underlyingAsset,
                _strikeAsset,
                _assetsRegistry,
                _expiryTime,
                _isCall,
                _strikePrice
            ),
            _qTokenSymbol(
                _underlyingAsset,
                _strikeAsset,
                _assetsRegistry,
                _expiryTime,
                _isCall,
                _strikePrice
            )
        )
        ERC20Permit(
            _qTokenName(
                _underlyingAsset,
                _strikeAsset,
                _assetsRegistry,
                _expiryTime,
                _isCall,
                _strikePrice
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
        priceRegistry = _priceRegistry;
        oracle = _oracle;
        expiryTime = _expiryTime;
        isCall = _isCall;
        strikePrice = _strikePrice;
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
                IPriceRegistry(priceRegistry).hasSettlementPrice(
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
        returns (QTokenInfo memory qTokenInfo)
    {
        qTokenInfo = QTokenInfo(
            underlyingAsset,
            strikeAsset,
            oracle,
            expiryTime,
            isCall,
            strikePrice
        );
    }
}
