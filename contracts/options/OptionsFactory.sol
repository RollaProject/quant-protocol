// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import {ClonesWithImmutableArgs} from "@rolla-finance/clones-with-immutable-args/ClonesWithImmutableArgs.sol";
import {QToken} from "././QToken.sol";
import "../libraries/OptionsUtils.sol";
import "../interfaces/IOptionsFactory.sol";
import "../interfaces/ICollateralToken.sol";
import "../interfaces/IPriceRegistry.sol";

/// @title Factory contract for Quant options
/// @author Rolla
/// @notice Creates tokens for long (QToken) and short (CollateralToken) positions
/// @dev This contract follows the factory design pattern
contract OptionsFactory is IOptionsFactory {
    using ClonesWithImmutableArgs for address;

    /// @inheritdoc IOptionsFactory
    address public immutable override strikeAsset;

    address public immutable override collateralToken;

    address public immutable override controller;

    address public immutable override priceRegistry;

    address public immutable override assetsRegistry;

    QToken public immutable implementation;

    uint8 public immutable override optionsDecimals = 18;

    /// @inheritdoc IOptionsFactory
    mapping(address => bool) public override isQToken;

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
        address _assetsRegistry,
        QToken _implementation
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
        require(
            address(_implementation) != address(0),
            "OptionsFactory: invalid QToken implementation address"
        );

        strikeAsset = _strikeAsset;
        collateralToken = _collateralToken;
        controller = _controller;
        priceRegistry = _priceRegistry;
        assetsRegistry = _assetsRegistry;
        implementation = _implementation;
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

        bytes memory data = OptionsUtils.getQTokenImmutableArgs(
            optionsDecimals,
            _underlyingAsset,
            strikeAsset,
            assetsRegistry,
            _oracle,
            _expiryTime,
            _isCall,
            _strikePrice,
            controller
        );

        newQToken = address(implementation).cloneDeterministic(
            OptionsUtils.SALT,
            data
        );

        newCollateralTokenId = ICollateralToken(collateralToken)
            .createCollateralToken(newQToken, address(0));

        isQToken[newQToken] = true;

        emit OptionCreated(
            newQToken,
            msg.sender,
            _underlyingAsset,
            _oracle,
            _expiryTime,
            _isCall,
            _strikePrice,
            newCollateralTokenId
        );
    }

    /// @inheritdoc IOptionsFactory
    function getTargetCollateralTokenId(
        address _underlyingAsset,
        address _qTokenAsCollateral,
        address _oracle,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice
    ) public override returns (uint256) {
        QTokenMetadata memory qTokenMetadata = OptionsUtils.getQTokenMetadata(
            _underlyingAsset,
            strikeAsset,
            assetsRegistry,
            _expiryTime,
            _isCall,
            _strikePrice
        );

        bytes memory data = abi.encodePacked(
            qTokenMetadata.name,
            qTokenMetadata.symbol,
            optionsDecimals,
            _underlyingAsset,
            strikeAsset,
            _oracle,
            _expiryTime,
            _isCall,
            _strikePrice,
            controller
        );

        return
            OptionsUtils.getTargetCollateralTokenId(
                collateralToken,
                _qTokenAsCollateral,
                address(implementation),
                data
            );
    }

    /// @inheritdoc IOptionsFactory
    function getTargetQTokenAddress(
        address _underlyingAsset,
        address _oracle,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice
    ) external override returns (address) {
        QTokenMetadata memory qTokenMetadata = OptionsUtils.getQTokenMetadata(
            _underlyingAsset,
            strikeAsset,
            assetsRegistry,
            _expiryTime,
            _isCall,
            _strikePrice
        );

        bytes memory data = abi.encodePacked(
            qTokenMetadata.name,
            qTokenMetadata.symbol,
            optionsDecimals,
            _underlyingAsset,
            strikeAsset,
            _oracle,
            _expiryTime,
            _isCall,
            _strikePrice,
            controller
        );

        return
            OptionsUtils.getTargetQTokenAddress(address(implementation), data);
    }

    /// @inheritdoc IOptionsFactory
    function getCollateralToken(
        address _underlyingAsset,
        address _qTokenAsCollateral,
        address _oracle,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice
    ) external override returns (uint256) {
        address qToken = getQToken(
            _underlyingAsset,
            _oracle,
            _expiryTime,
            _isCall,
            _strikePrice
        );

        uint256 id = ICollateralToken(collateralToken).getCollateralTokenId(
            qToken,
            _qTokenAsCollateral
        );

        (address storedQToken, ) = ICollateralToken(collateralToken).idToInfo(
            id
        );
        return storedQToken != address(0) ? id : 0;
    }

    /// @inheritdoc IOptionsFactory
    function getQToken(
        address _underlyingAsset,
        address _oracle,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice
    ) public override returns (address) {
        uint256 collateralTokenId = getTargetCollateralTokenId(
            _underlyingAsset,
            address(0),
            _oracle,
            _expiryTime,
            _isCall,
            _strikePrice
        );

        return address(0);
    }
}
