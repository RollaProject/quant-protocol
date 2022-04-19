// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import "@openzeppelin/contracts/utils/Create2.sol";
import "../options/QToken.sol";
import "../interfaces/ICollateralToken.sol";
import "../interfaces/IOracleRegistry.sol";
import "../interfaces/IProviderOracleManager.sol";
import "../interfaces/IQToken.sol";
import "../interfaces/IAssetsRegistry.sol";

/// @title Options utilities for Quant's QToken and CollateralToken
/// @author Rolla
/// @dev This library must be deployed and linked while deploying contracts that use it
library OptionsUtils {
    /// @notice constant salt because options will only be deployed with the same parameters once
    bytes32 public constant SALT = bytes32("ROLLA.FINANCE");

    /// @notice get the address at which a new QToken with the given parameters would be deployed
    /// @notice return the exact address the QToken will be deployed at with OpenZeppelin's Create2
    /// library computeAddress function
    /// @param _underlyingAsset asset that the option references
    /// @param _strikeAsset asset that the strike is denominated in
    /// @param _oracle price oracle for the option underlying
    /// @param _priceRegistry address of the PriceRegistry contract
    /// @param _assetsRegistry address of the AssetsRegistry contract
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @return the address where a QToken would be deployed
    function getTargetQTokenAddress(
        address _underlyingAsset,
        address _strikeAsset,
        address _priceRegistry,
        address _assetsRegistry,
        address _oracle,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice
    ) internal view returns (address) {
        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(
                type(QToken).creationCode,
                abi.encode(
                    _underlyingAsset,
                    _strikeAsset,
                    _priceRegistry,
                    _assetsRegistry,
                    _oracle,
                    _expiryTime,
                    _isCall,
                    _strikePrice
                )
            )
        );

        return Create2.computeAddress(SALT, bytecodeHash);
    }

    /// @notice get the id that a CollateralToken with the given parameters would have
    /// @param _underlyingAsset asset that the option references
    /// @param _strikeAsset asset that the strike is denominated in
    /// @param _oracle price oracle for the option underlying
    /// @param _priceRegistry address of the PriceRegistry contract
    /// @param _assetsRegistry address of the AssetsRegistry contract
    /// @param _qTokenAsCollateral initial spread collateral
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @return the id that a CollateralToken would have
    function getTargetCollateralTokenId(
        ICollateralToken _collateralToken,
        address _underlyingAsset,
        address _qTokenAsCollateral,
        address _strikeAsset,
        address _priceRegistry,
        address _assetsRegistry,
        address _oracle,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice
    ) internal view returns (uint256) {
        address qToken = getTargetQTokenAddress(
            _underlyingAsset,
            _strikeAsset,
            _priceRegistry,
            _assetsRegistry,
            _oracle,
            _expiryTime,
            _isCall,
            _strikePrice
        );
        return
            _collateralToken.getCollateralTokenId(qToken, _qTokenAsCollateral);
    }

    /// @notice Checks if the given option parameters are valid for creation in the Quant Protocol
    /// @param _underlyingAsset asset that the option is for
    /// @param _oracle price oracle for the option underlying
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _assetsRegistry address of the AssetsRegistry contract
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
            IOracleRegistry(_oracleRegistry).isOracleRegistered(_oracle),
            "OptionsFactory: Oracle is not registered in OracleRegistry"
        );

        require(
            IProviderOracleManager(_oracle).getAssetOracle(_underlyingAsset) !=
                address(0),
            "OptionsFactory: Asset does not exist in oracle"
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
}
