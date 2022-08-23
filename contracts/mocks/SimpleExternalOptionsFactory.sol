// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import {ClonesWithImmutableArgs} from "@rolla-finance/clones-with-immutable-args/ClonesWithImmutableArgs.sol";
import {QToken} from "../options/QToken.sol";
import {CollateralToken} from "../options/CollateralToken.sol";
import "../libraries/OptionsUtils.sol";

contract SimpleExternalOptionsFactory {
    using ClonesWithImmutableArgs for address;

    QToken public immutable implementation;
    CollateralToken public immutable collateralToken;
    address public immutable assetsRegistry;
    uint8 public immutable optionsDecimals = 18;
    bytes32 public immutable salt = OptionsUtils.SALT;

    constructor(address _assetsRegistry, address _implementation) {
        implementation = QToken(_implementation);
        collateralToken = new CollateralToken(
            "Quant Protocol",
            "1.0.0",
            "https://tokens.rolla.finance/{id}.json"
        );
        assetsRegistry = _assetsRegistry;

        collateralToken.setOptionsFactory(address(this));
    }

    function createOption(
        address underlyingAsset,
        address strikeAsset,
        address oracle,
        uint88 expiryTime,
        bool isCall,
        uint256 strikePrice,
        address controller
    )
        public
        returns (address newQToken, uint256 newCollateralTokenId)
    {
        bytes memory immutableArgsData;

        assembly ("memory-safe") {
            // set the immutable args data pointer to the initial free memory pointer
            immutableArgsData := mload(0x40)

            // set the free memory pointer to 288 bytes after its current value, leaving
            // room for the total immutable args size followed by the QToken name and
            // symbol strings to be placed before the other immutable args
            mstore(0x40, add(immutableArgsData, 0x100))
        }

        abi.encodePacked(
            OptionsUtils.OPTIONS_DECIMALS,
            underlyingAsset,
            strikeAsset,
            oracle,
            expiryTime,
            isCall,
            strikePrice,
            controller
        );

        OptionsUtils.addNameAndSymbolToImmutableArgs(immutableArgsData, assetsRegistry);

        newQToken = address(implementation).cloneDeterministic(salt, immutableArgsData);

        newCollateralTokenId = collateralToken.createOptionCollateralToken(newQToken);
    }

    function getQToken(
        address underlyingAsset,
        address strikeAsset,
        address oracle,
        uint88 expiryTime,
        bool isCall,
        uint256 strikePrice,
        address controller
    )
        public
        view
        returns (address qToken, bool exists)
    {
        bytes memory immutableArgsData;

        assembly ("memory-safe") {
            // set the immutable args data pointer to the initial free memory pointer
            immutableArgsData := mload(0x40)

            // set the free memory pointer to 288 bytes after its current value, leaving
            // room for the total immutable args size followed by the QToken name and
            // symbol strings to be placed before the other immutable args
            mstore(0x40, add(immutableArgsData, 0x100))
        }

        abi.encodePacked(
            OptionsUtils.OPTIONS_DECIMALS,
            underlyingAsset,
            strikeAsset,
            oracle,
            expiryTime,
            isCall,
            strikePrice,
            controller
        );

        OptionsUtils.addNameAndSymbolToImmutableArgs(immutableArgsData, assetsRegistry);

        (qToken, exists) =
            ClonesWithImmutableArgs.predictDeterministicAddress(address(implementation), salt, immutableArgsData);
    }

    function getCollateralToken(
        address underlyingAsset,
        address qTokenAsCollateral,
        address strikeAsset,
        address oracle,
        uint88 expiryTime,
        bool isCall,
        uint256 strikePrice,
        address controller
    )
        public
        view
        returns (uint256 id, bool exists)
    {
        (address qToken,) = getQToken(underlyingAsset, strikeAsset, oracle, expiryTime, isCall, strikePrice, controller);

        id = collateralToken.getCollateralTokenId(qToken, qTokenAsCollateral);

        (qToken,) = collateralToken.idToInfo(id);

        exists = qToken != address(0);
    }
}
