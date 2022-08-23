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
        OptionsUtils.validateOptionParameters(
            oracleRegistry, _underlyingAsset, assetsRegistry, _oracle, _expiryTime, _strikePrice
        );

        bytes memory immutableArgsData =
            getImmutableArgsData(_underlyingAsset, _oracle, _expiryTime, _isCall, _strikePrice);

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
        bytes memory immutableArgsData =
            getImmutableArgsData(_underlyingAsset, _oracle, _expiryTime, _isCall, _strikePrice);

        (qToken, exists) = ClonesWithImmutableArgs.predictDeterministicAddress(
            address(implementation), OptionsUtils.SALT, immutableArgsData
        );
    }

    function getImmutableArgsData(
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
            immutableArgsData := mload(0x40)

            // set the free memory pointer to 256 bytes after its current value, leaving
            // room for the total immutable args length followed by the QToken name and
            // symbol 128-byte strings to be placed before the other packed immutable args
            mstore(0x40, add(immutableArgsData, 0x100))
        }

        // place the initial packed immutable args in memory, with their total length
        // stored at immutableArgsData + 0x100 (the current free memory pointer) and
        // with the args contents starting at immutableArgs + 0x120
        abi.encodePacked(
            OptionsUtils.OPTIONS_DECIMALS,
            _underlyingAsset,
            strikeAsset,
            _oracle,
            _expiryTime,
            _isCall,
            _strikePrice,
            controller
        );

        OptionsUtils.addNameAndSymbolToImmutableArgs(immutableArgsData, assetsRegistry);
    }
}
