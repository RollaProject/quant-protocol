// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import "../libraries/OptionsUtils.sol";
import "../interfaces/IOptionsFactory.sol";
import "../interfaces/IProviderOracleManager.sol";
import "../interfaces/IOracleRegistry.sol";
import "../interfaces/IAssetsRegistry.sol";
import "../interfaces/ICollateralToken.sol";
import "../interfaces/IPriceRegistry.sol";

/// @title Factory contract for Quant options
/// @author Rolla
/// @notice Creates tokens for long (QToken) and short (CollateralToken) positions
/// @dev This contract follows the factory design pattern
contract OptionsFactory is IOptionsFactory {
    /// @inheritdoc IOptionsFactory
    address[] public override qTokens;

    /// @inheritdoc IOptionsFactory
    address public override strikeAsset;

    ICollateralToken public override collateralToken;

    address public override controller;

    address public override priceRegistry;

    address public override assetsRegistry;

    mapping(uint256 => address) private _collateralTokenIdToQTokenAddress;

    /// @inheritdoc IOptionsFactory
    mapping(address => uint256)
        public
        override qTokenAddressToCollateralTokenId;

    /// @notice Initializes a new options factory
    /// @param _strikeAsset address of the asset used to denominate strike prices
    /// for options created through this factory
    /// @param _collateralToken address of the CollateralToken contract
    /// @param _controller address of the Quant Controller contract
    constructor(
        address _strikeAsset,
        address _collateralToken,
        address _controller,
        address _priceRegistry,
        address _assetsRegistry
    ) {
        require(
            _strikeAsset != address(0),
            "OptionsFactory: invalid strike asset address"
        );
        require(
            _collateralToken != address(0),
            "OptionsFactory: invalid CollateralToken address"
        );
        require(
            _controller != address(0),
            "OptionsFactory: invalid controller address"
        );
        require(
            _priceRegistry != address(0),
            "OptionsFactory: invalid price registry address"
        );
        require(
            _assetsRegistry != address(0),
            "OptionsFactory: invalid assets registry address"
        );

        strikeAsset = _strikeAsset;
        collateralToken = ICollateralToken(_collateralToken);
        controller = _controller;
        priceRegistry = _priceRegistry;
        assetsRegistry = _assetsRegistry;
    }

    /// @inheritdoc IOptionsFactory
    function createOption(
        address _underlyingAsset,
        address _oracle,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice
    )
        external
        override
        returns (address newQToken, uint256 newCollateralTokenId)
    {
        OptionsUtils.validateOptionParameters(
            IPriceRegistry(priceRegistry).oracleRegistry(),
            _underlyingAsset,
            assetsRegistry,
            _oracle,
            _expiryTime,
            _strikePrice
        );

        newCollateralTokenId = OptionsUtils.getTargetCollateralTokenId(
            collateralToken,
            _underlyingAsset,
            address(0),
            strikeAsset,
            priceRegistry,
            assetsRegistry,
            _oracle,
            _expiryTime,
            _isCall,
            _strikePrice
        );

        require(
            _collateralTokenIdToQTokenAddress[newCollateralTokenId] ==
                address(0),
            "option already created"
        );

        newQToken = address(
            new QToken{salt: OptionsUtils.SALT}(
                _underlyingAsset,
                strikeAsset,
                priceRegistry,
                assetsRegistry,
                _oracle,
                _expiryTime,
                _isCall,
                _strikePrice
            )
        );

        QToken(newQToken).transferOwnership(controller);

        _collateralTokenIdToQTokenAddress[newCollateralTokenId] = newQToken;
        qTokens.push(newQToken);

        qTokenAddressToCollateralTokenId[newQToken] = newCollateralTokenId;

        emit OptionCreated(
            newQToken,
            msg.sender,
            _underlyingAsset,
            _oracle,
            _expiryTime,
            _isCall,
            _strikePrice,
            newCollateralTokenId,
            qTokens.length
        );

        collateralToken.createCollateralToken(newQToken, address(0));
    }

    /// @inheritdoc IOptionsFactory
    function getTargetCollateralTokenId(
        address _underlyingAsset,
        address _qTokenAsCollateral,
        address _oracle,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice
    ) external view override returns (uint256) {
        return
            OptionsUtils.getTargetCollateralTokenId(
                collateralToken,
                _underlyingAsset,
                _qTokenAsCollateral,
                strikeAsset,
                priceRegistry,
                assetsRegistry,
                _oracle,
                _expiryTime,
                _isCall,
                _strikePrice
            );
    }

    /// @inheritdoc IOptionsFactory
    function getTargetQTokenAddress(
        address _underlyingAsset,
        address _oracle,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice
    ) external view override returns (address) {
        return
            OptionsUtils.getTargetQTokenAddress(
                _underlyingAsset,
                strikeAsset,
                priceRegistry,
                assetsRegistry,
                _oracle,
                _expiryTime,
                _isCall,
                _strikePrice
            );
    }

    /// @inheritdoc IOptionsFactory
    function getCollateralToken(
        address _underlyingAsset,
        address _qTokenAsCollateral,
        address _oracle,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice
    ) external view override returns (uint256) {
        address qToken = getQToken(
            _underlyingAsset,
            _oracle,
            _expiryTime,
            _isCall,
            _strikePrice
        );

        uint256 id = collateralToken.getCollateralTokenId(
            qToken,
            _qTokenAsCollateral
        );

        (address storedQToken, ) = collateralToken.idToInfo(id);
        return storedQToken != address(0) ? id : 0;
    }

    /// @inheritdoc IOptionsFactory
    function getOptionsLength() external view override returns (uint256) {
        return qTokens.length;
    }

    /// @inheritdoc IOptionsFactory
    function isQToken(address _qToken) external view override returns (bool) {
        return qTokenAddressToCollateralTokenId[_qToken] != 0;
    }

    /// @inheritdoc IOptionsFactory
    function getQToken(
        address _underlyingAsset,
        address _oracle,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice
    ) public view override returns (address) {
        uint256 collateralTokenId = OptionsUtils.getTargetCollateralTokenId(
            collateralToken,
            _underlyingAsset,
            address(0),
            strikeAsset,
            priceRegistry,
            assetsRegistry,
            _oracle,
            _expiryTime,
            _isCall,
            _strikePrice
        );

        return _collateralTokenIdToQTokenAddress[collateralTokenId];
    }
}
