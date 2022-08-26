// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import {ClonesWithImmutableArgs} from "@rolla-finance/clones-with-immutable-args/ClonesWithImmutableArgs.sol";
import {QToken} from "./QToken.sol";
import "../libraries/OptionsUtils.sol";
import "../interfaces/IOptionsFactory.sol";
import "../interfaces/ICollateralToken.sol";

/// @title Factory contract for Quant options
/// @author Rolla
/// @notice Creates tokens for long (QToken) and short (CollateralToken) positions
/// @dev This contract follows the factory design pattern
contract OptionsFactory is IOptionsFactory {
    using ClonesWithImmutableArgs for address;

    /// @inheritdoc IOptionsFactory
    address public immutable override strikeAsset;

    /// @inheritdoc IOptionsFactory
    address public immutable override collateralToken;

    /// @inheritdoc IOptionsFactory
    address public immutable override controller;

    /// @inheritdoc IOptionsFactory
    address public immutable override oracleRegistry;

    /// @inheritdoc IOptionsFactory
    address public immutable override assetsRegistry;

    /// @inheritdoc IOptionsFactory
    QToken public immutable implementation;

    /// @inheritdoc IOptionsFactory
    mapping(address => bool) public override isQToken;

    /// @notice Initializes a new options factory
    /// @param _strikeAsset address of the asset used to denominate strike prices
    /// for options created through this factory
    /// @param _collateralToken address of the CollateralToken contract
    /// @param _controller address of the Quant Controller contract
    /// @param _oracleRegistry address of the OracleRegistry contract
    /// @param _assetsRegistry address of the AssetsRegistry contract
    /// @param _implementation a QToken implementation contract, to be used when creating QToken clones
    /// for the options created through this factory
    constructor(
        address _strikeAsset,
        address _collateralToken,
        address _controller,
        address _oracleRegistry,
        address _assetsRegistry,
        QToken _implementation
    ) {
        require(_strikeAsset != address(0), "OptionsFactory: invalid strike asset address");
        require(_collateralToken != address(0), "OptionsFactory: invalid CollateralToken address");
        require(_controller != address(0), "OptionsFactory: invalid controller address");
        require(_oracleRegistry != address(0), "OptionsFactory: invalid oracle registry address");
        require(_assetsRegistry != address(0), "OptionsFactory: invalid assets registry address");
        require(address(_implementation) != address(0), "OptionsFactory: invalid QToken implementation address");

        strikeAsset = _strikeAsset;
        collateralToken = _collateralToken;
        controller = _controller;
        oracleRegistry = _oracleRegistry;
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
        bytes memory assetProperties = OptionsUtils.getAssetProperties(_underlyingAsset, assetsRegistry);

        OptionsUtils.validateOptionParameters(
            assetProperties, oracleRegistry, _underlyingAsset, _oracle, _expiryTime, _strikePrice
        );

        bytes memory immutableArgsData =
            getImmutableArgsData(assetProperties, _underlyingAsset, _oracle, _expiryTime, _isCall, _strikePrice);

        newQToken = address(implementation).cloneDeterministic(OptionsUtils.SALT, immutableArgsData);

        newCollateralTokenId = ICollateralToken(collateralToken).createOptionCollateralToken(newQToken);

        isQToken[newQToken] = true;

        emit OptionCreated(
            newQToken, msg.sender, _underlyingAsset, _oracle, _expiryTime, _isCall, _strikePrice, newCollateralTokenId
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
    )
        external
        view
        override
        returns (uint256 id, bool exists)
    {
        (address qToken,) = getQToken(_underlyingAsset, _oracle, _expiryTime, _isCall, _strikePrice);

        id = ICollateralToken(collateralToken).getCollateralTokenId(qToken, _qTokenAsCollateral);

        (qToken,) = ICollateralToken(collateralToken).idToInfo(id);

        exists = qToken != address(0);
    }

    /// @inheritdoc IOptionsFactory
    function getQToken(
        address _underlyingAsset,
        address _oracle,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice
    )
        public
        view
        override
        returns (address qToken, bool exists)
    {
        bytes memory assetProperties = OptionsUtils.getAssetProperties(_underlyingAsset, assetsRegistry);

        bytes memory immutableArgsData =
            getImmutableArgsData(assetProperties, _underlyingAsset, _oracle, _expiryTime, _isCall, _strikePrice);

        (qToken, exists) = ClonesWithImmutableArgs.predictDeterministicAddress(
            address(implementation), OptionsUtils.SALT, immutableArgsData
        );
    }

    /// @notice generates the data to be used to create a new QToken clone with immutable args
    /// @param _assetProperties underlying asset properties as stored in the AssetsRegistry
    /// @param _underlyingAsset asset that the option references
    /// @param _oracle price oracle for the option underlying
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @return immutableArgsData the packed data to be used as the QToken clone immutable args
    function getImmutableArgsData(
        bytes memory _assetProperties,
        address _underlyingAsset,
        address _oracle,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice
    )
        internal
        view
        returns (bytes memory immutableArgsData)
    {
        // put immutable variables in the stack since inline assembly can't otherwise access them
        address _strikeAsset = strikeAsset;
        address _controller = controller;

        // where the manually packed args will start in memory
        uint256 packedArgsStart;

        /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    Immutable Args Memory Layout
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
        /* 
        |  immutableArgsData    | --> |         name           | --> |          symbol          | --> |      packed args       |
        |     freeMemPtr        | --> |    freeMemPtr + 0x20   | --> |     freeMemPtr + 0xa0    | --> |  freeMemPtr + 0x120    |
        | immutable args length | --> | name string w/o length | --> | symbol string w/o length | --> | packed args w/o length |
        */
        assembly ("memory-safe") {
            // set the immutable args data pointer to the initial free memory pointer
            immutableArgsData := mload(FREE_MEM_PTR)

            // manually pack the ending immutable args data 288 bytes after where the total
            // immutable args length will be placed followed by the QToken name and
            // symbol 128-byte strings
            packedArgsStart := add(immutableArgsData, add(ONE_WORD, NAME_AND_SYMBOL_LENGTH))
            mstore(packedArgsStart, shl(ONE_BYTE_OFFSET, and(OPTIONS_DECIMALS, MASK_8)))
            mstore(add(packedArgsStart, 1), shl(ADDRESS_OFFSET, and(_underlyingAsset, MASK_160)))
            mstore(add(packedArgsStart, 21), shl(ADDRESS_OFFSET, and(_strikeAsset, MASK_160)))
            mstore(add(packedArgsStart, 41), shl(ADDRESS_OFFSET, and(_oracle, MASK_160)))
            mstore(add(packedArgsStart, 61), shl(UINT88_OFFSET, and(_expiryTime, MASK_88)))
            mstore(add(packedArgsStart, 72), shl(ONE_BYTE_OFFSET, and(_isCall, MASK_8)))
            mstore(add(packedArgsStart, 73), and(_strikePrice, MASK_256))
            mstore(add(packedArgsStart, 105), shl(ADDRESS_OFFSET, and(_controller, MASK_160)))

            // update the free memory pointer to after the packed args
            mstore(FREE_MEM_PTR, add(packedArgsStart, PACKED_ARGS_LENGTH))
        }

        OptionsUtils.addNameAndSymbolToImmutableArgs(_assetProperties, immutableArgsData, packedArgsStart);
    }
}
