// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/utils/Create2.sol";
import "../options/QToken.sol";
import "../interfaces/ICollateralToken.sol";
import "../interfaces/IOracleRegistry.sol";
import "../interfaces/IProviderOracleManager.sol";
import "../interfaces/IQuantConfig.sol";

/// @title Options utilities for Quant's QToken and CollateralToken
/// @author Quant Finance
/// @dev This library must be deployed and linked while deploying contracts that use it
library OptionsUtils {
    /// @notice constant salt because options will only be deployed with the same parameters once
    bytes32 public constant SALT = bytes32("QUANT.FINANCE");

    /// @notice get the address at which a new QToken with the given parameters would be deployed
    /// @notice return the exact address the QToken will be deployed at with OpenZeppelin's Create2
    /// library computeAddress function
    /// @param _underlyingAsset asset that the option references
    /// @param _strikeAsset asset that the strike is denominated in
    /// @param _oracle price oracle for the option underlying
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @return the address where a QToken would be deployed
    function getTargetQTokenAddress(
        address _quantConfig,
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    ) internal view returns (address) {
        bytes32 bytecodeHash =
            keccak256(
                abi.encodePacked(
                    type(QToken).creationCode,
                    abi.encode(
                        _quantConfig,
                        _underlyingAsset,
                        _strikeAsset,
                        _oracle,
                        _strikePrice,
                        _expiryTime,
                        _isCall
                    )
                )
            );

        return Create2.computeAddress(SALT, bytecodeHash);
    }

    /// @notice get the id that a CollateralToken with the given parameters would have
    /// @param _underlyingAsset asset that the option references
    /// @param _strikeAsset asset that the strike is denominated in
    /// @param _oracle price oracle for the option underlying
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _qTokenAsCollateral initial spread collateral
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @return the id that a CollateralToken would have
    function getTargetCollateralTokenId(
        ICollateralToken _collateralToken,
        address _quantConfig,
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        address _qTokenAsCollateral,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    ) internal view returns (uint256) {
        address qToken =
            getTargetQTokenAddress(
                _quantConfig,
                _underlyingAsset,
                _strikeAsset,
                _oracle,
                _strikePrice,
                _expiryTime,
                _isCall
            );
        return
            _collateralToken.getCollateralTokenId(qToken, _qTokenAsCollateral);
    }

    function validateOptionParameters(
        address _underlyingAsset,
        address _oracle,
        uint256 _expiryTime,
        address _quantConfig
    ) internal view {
        require(
            _expiryTime > block.timestamp,
            "OptionsFactory: given expiry time is in the past"
        );

        IOracleRegistry oracleRegistry =
            IOracleRegistry(
                IQuantConfig(_quantConfig).protocolAddresses(
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
    }

    function isInAssetsRegistry(address _asset, address _quantConfig)
        internal
        view
        returns (bool)
    {
        string memory symbol;
        (, symbol, , ) = IAssetsRegistry(
            IQuantConfig(_quantConfig).protocolAddresses(
                ProtocolValue.encode("assetsRegistry")
            )
        )
            .assetProperties(_asset);

        return bytes(symbol).length != 0;
    }
}