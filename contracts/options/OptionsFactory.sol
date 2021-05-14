// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma abicoder v2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../libraries/OptionsUtils.sol";
import "../interfaces/IOptionsFactory.sol";
import "../interfaces/IQuantConfig.sol";
import "../interfaces/IProviderOracleManager.sol";
import "../interfaces/IOracleRegistry.sol";
import "../interfaces/IAssetsRegistry.sol";
import "../interfaces/ICollateralToken.sol";

/// @title Factory contract for Quant options
/// @author Quant Finance
/// @notice Creates tokens for long (QToken) and short (CollateralToken) positions
/// @dev This contract follows the factory design pattern
contract OptionsFactory is IOptionsFactory {
    using SafeMath for uint256;

    /// @inheritdoc IOptionsFactory
    address[] public override qTokens;

    IQuantConfig public override quantConfig;

    ICollateralToken public override collateralToken;

    mapping(uint256 => address) private _collateralTokenIdToQTokenAddress;

    /// @inheritdoc IOptionsFactory
    mapping(address => uint256)
        public
        override qTokenAddressToCollateralTokenId;

    /// @notice Initializes a new options factory
    /// @param _quantConfig the address of the Quant system configuration contract
    /// @param _collateralToken address of the CollateralToken contract
    constructor(address _quantConfig, address _collateralToken) {
        quantConfig = IQuantConfig(_quantConfig);
        collateralToken = ICollateralToken(_collateralToken);
    }

    /// @inheritdoc IOptionsFactory
    function getTargetQTokenAddress(
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    ) external view override returns (address) {
        return
            OptionsUtils.getTargetQTokenAddress(
                address(quantConfig),
                _underlyingAsset,
                _strikeAsset,
                _oracle,
                _strikePrice,
                _expiryTime,
                _isCall
            );
    }

    /// @inheritdoc IOptionsFactory
    function getTargetCollateralTokenId(
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        address _qTokenAsCollateral,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    ) external view override returns (uint256) {
        return
            OptionsUtils.getTargetCollateralTokenId(
                collateralToken,
                address(quantConfig),
                _underlyingAsset,
                _strikeAsset,
                _oracle,
                _qTokenAsCollateral,
                _strikePrice,
                _expiryTime,
                _isCall
            );
    }

    /// @inheritdoc IOptionsFactory
    function createOption(
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    )
        external
        override
        returns (address newQToken, uint256 newCollateralTokenId)
    {
        require(
            _expiryTime > block.timestamp,
            "OptionsFactory: given expiry time is in the past"
        );

        IOracleRegistry oracleRegistry =
            IOracleRegistry(
                quantConfig.protocolAddresses(
                    ProtocolValue.encode("oracleRegistry")
                )
            );

        require(
            oracleRegistry.isOracleRegistered(_oracle),
            "OptionsFactory: Oracle is not registered in OracleRegistry"
        );

        require(
            IProviderOracleManager(_oracle).getAssetOracle(_underlyingAsset) !=
                address(0),
            "OptionsFactory: Asset does not exist in oracle"
        );

        require(
            oracleRegistry.isOracleActive(_oracle),
            "OptionsFactory: Oracle is not active in the OracleRegistry"
        );

        newCollateralTokenId = OptionsUtils.getTargetCollateralTokenId(
            collateralToken,
            address(quantConfig),
            _underlyingAsset,
            _strikeAsset,
            _oracle,
            address(0),
            _strikePrice,
            _expiryTime,
            _isCall
        );

        require(
            _collateralTokenIdToQTokenAddress[newCollateralTokenId] ==
                address(0),
            "OptionsFactory: option already created"
        );
        require(
            _isCall || _strikePrice > 0,
            "OptionsFactory: strike for put can't be 0"
        );

        {
            string memory symbol;
            (, symbol, , ) = IAssetsRegistry(
                quantConfig.protocolAddresses(
                    ProtocolValue.encode("assetsRegistry")
                )
            )
                .assetProperties(_underlyingAsset);
            require(
                bytes(symbol).length != 0,
                "OptionsFactory: underlying is not in the assets registry"
            );
        }

        newQToken = address(
            new QToken{salt: OptionsUtils.SALT}(
                address(quantConfig),
                _underlyingAsset,
                _strikeAsset,
                _oracle,
                _strikePrice,
                _expiryTime,
                _isCall
            )
        );

        _collateralTokenIdToQTokenAddress[newCollateralTokenId] = newQToken;
        qTokens.push(newQToken);

        qTokenAddressToCollateralTokenId[newQToken] = newCollateralTokenId;

        emit OptionCreated(
            newQToken,
            msg.sender,
            _underlyingAsset,
            _strikeAsset,
            _oracle,
            _strikePrice,
            _expiryTime,
            newCollateralTokenId,
            qTokens.length,
            _isCall
        );

        collateralToken.createCollateralToken(newQToken, address(0));
    }

    /// @inheritdoc IOptionsFactory
    function getCollateralToken(
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        address _qTokenAsCollateral,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    ) public view override returns (uint256) {
        address qToken =
            getQToken(
                _underlyingAsset,
                _strikeAsset,
                _oracle,
                _strikePrice,
                _expiryTime,
                _isCall
            );

        uint256 id =
            collateralToken.getCollateralTokenId(qToken, _qTokenAsCollateral);

        (address storedQToken, ) = collateralToken.idToInfo(id);
        return storedQToken != address(0) ? id : 0;
    }

    /// @inheritdoc IOptionsFactory
    function getQToken(
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    ) public view override returns (address) {
        uint256 collateralTokenId =
            OptionsUtils.getTargetCollateralTokenId(
                collateralToken,
                address(quantConfig),
                _underlyingAsset,
                _strikeAsset,
                _oracle,
                address(0),
                _strikePrice,
                _expiryTime,
                _isCall
            );

        return _collateralTokenIdToQTokenAddress[collateralTokenId];
    }

    /// @inheritdoc IOptionsFactory
    function getOptionsLength() external view override returns (uint256) {
        return qTokens.length;
    }

    /// @inheritdoc IOptionsFactory
    function isQToken(address _qToken) external view override returns (bool) {
        return qTokenAddressToCollateralTokenId[_qToken] != 0;
    }
}
