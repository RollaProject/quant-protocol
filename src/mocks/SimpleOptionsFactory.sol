// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {ClonesWithImmutableArgs} from "@rolla-finance/clones-with-immutable-args/src/ClonesWithImmutableArgs.sol";
import {QToken} from "../options/QToken.sol";
import {CollateralToken} from "../options/CollateralToken.sol";
import "../libraries/OptionsUtils.sol";

contract SimpleOptionsFactory {
    using ClonesWithImmutableArgs for address;

    QToken public immutable implementation;
    CollateralToken public immutable collateralToken;
    address public immutable assetsRegistry;
    uint8 public immutable optionsDecimals = 18;
    bytes32 public immutable salt = OptionsUtils.SALT;
    address public immutable strikeAsset;
    address public immutable controller;

    constructor(address _assetsRegistry, address _strikeAsset, address _controller) {
        implementation = new QToken();
        collateralToken = new CollateralToken(
            "Quant Protocol",
            "1.0.0",
            "https://tokens.rolla.finance/{id}.json"
        );
        assetsRegistry = _assetsRegistry;

        collateralToken.setOptionsFactory(address(this));

        strikeAsset = _strikeAsset;
        controller = _controller;
    }

    function createOption(address underlyingAsset, address oracle, uint88 expiryTime, bool isCall, uint256 strikePrice)
        public
        returns (address newQToken, uint256 newCollateralTokenId)
    {
        bytes memory assetProperties = OptionsUtils.getAssetProperties(underlyingAsset, assetsRegistry);

        bytes memory immutableArgsData =
            getImmutableArgsData(assetProperties, underlyingAsset, oracle, expiryTime, isCall, strikePrice);

        newQToken = address(implementation).cloneDeterministic(salt, immutableArgsData);

        newCollateralTokenId = collateralToken.createOptionCollateralToken(newQToken);
    }

    function getQToken(address underlyingAsset, address oracle, uint88 expiryTime, bool isCall, uint256 strikePrice)
        public
        view
        returns (address qToken, bool exists)
    {
        bytes memory assetProperties = OptionsUtils.getAssetProperties(underlyingAsset, assetsRegistry);

        bytes memory immutableArgsData =
            getImmutableArgsData(assetProperties, underlyingAsset, oracle, expiryTime, isCall, strikePrice);

        (qToken, exists) =
            ClonesWithImmutableArgs.predictDeterministicAddress(address(implementation), salt, immutableArgsData);
    }

    function getCollateralToken(
        address underlyingAsset,
        address qTokenAsCollateral,
        address oracle,
        uint88 expiryTime,
        bool isCall,
        uint256 strikePrice
    ) public view returns (uint256 id, bool exists) {
        (address qToken,) = getQToken(underlyingAsset, oracle, expiryTime, isCall, strikePrice);

        id = collateralToken.getCollateralTokenId(qToken, qTokenAsCollateral);

        (qToken,) = collateralToken.idToInfo(id);

        exists = qToken != address(0);
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
    ) internal view returns (bytes memory immutableArgsData) {
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
        |     freeMemPtr        | --> |    freeMemPtr + 32     | --> |     freeMemPtr + 160     | --> |  freeMemPtr + 288      |
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
