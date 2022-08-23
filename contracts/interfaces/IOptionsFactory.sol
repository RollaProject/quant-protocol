// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../options/QToken.sol";

interface IOptionsFactory {
    /// @notice emitted when the factory creates a new option
    event OptionCreated(
        address qTokenAddress,
        address creator,
        address indexed underlying,
        address oracle,
        uint88 expiry,
        bool isCall,
        uint256 strikePrice,
        uint256 collateralTokenId
    );

    /// @notice Creates new options (QToken + CollateralToken)
    /// @dev Uses clones-with-immutable-args to create new QTokens from a single
    /// implementation contract
    /// @dev The CREATE2 opcode is used to deterministically deploy new QToken clones
    /// @param _underlyingAsset asset that the option references
    /// @param _oracle price oracle for the option underlying
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @param _strikePrice strike price with as many decimals in the strike asset
    function createOption(
        address _underlyingAsset,
        address _oracle,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice
    )
        external
        returns (address, uint256);

    /// @notice get the CollateralToken id for a given option, and whether it has
    /// already been created
    /// @param _underlyingAsset asset that the option references
    /// @param _qTokenAsCollateral initial spread collateral
    /// @param _oracle price oracle for the option underlying
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @return id of the requested CollateralToken
    /// @return true if the CollateralToken has already been created, false otherwise
    function getCollateralToken(
        address _underlyingAsset,
        address _qTokenAsCollateral,
        address _oracle,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice
    )
        external
        view
        returns (uint256, bool);

    /// @notice get the QToken address for a given option, and whether it has
    /// already been created
    /// @param _underlyingAsset asset that the option references
    /// @param _oracle price oracle for the option underlying
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @return address of the requested QToken
    /// @return true if the QToken has already been created, false otherwise
    function getQToken(
        address _underlyingAsset,
        address _oracle,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice
    )
        external
        view
        returns (address, bool);

    /// @notice get the strike asset used for options created by the factory
    /// @return the strike asset address
    function strikeAsset() external view returns (address);

    /// @notice get the collateral token used for options created by the factory
    /// @return the collateral token address
    function collateralToken() external view returns (address);

    /// @notice get the Quant Controller that mints and burns options created by the factory
    /// @return the Quant Controller address
    function controller() external view returns (address);

    /// @notice get the OracleRegistry that stores and manages oracles used with options created by the factory
    function oracleRegistry() external view returns (address);

    /// @notice get the AssetsRegistry that stores data about the underlying assets for options created by the factory
    /// @return the AssetsRegistry address
    function assetsRegistry() external view returns (address);

    /// @notice get the QToken implementation that is used to create options through the factory
    /// @return the QToken implementation address
    function implementation() external view returns (QToken);

    /// @notice checks if an address is a QToken
    /// @return true if the given address represents a registered QToken.
    /// false otherwise
    function isQToken(address) external view returns (bool);
}
