// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import {ClonesWithImmutableArgs} from "@rolla-finance/clones-with-immutable-args/ClonesWithImmutableArgs.sol";
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

    constructor(address _assetsRegistry) {
        implementation = new QToken();
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
    ) public returns (address newQToken, uint256 newCollateralTokenId) {
        bytes memory data = OptionsUtils.getQTokenImmutableArgs(
            optionsDecimals,
            underlyingAsset,
            strikeAsset,
            assetsRegistry,
            oracle,
            expiryTime,
            isCall,
            strikePrice,
            controller
        );

        newQToken = address(implementation).cloneDeterministic(salt, data);

        newCollateralTokenId = collateralToken.createOptionCollateralToken(
            newQToken
        );
    }

    function getQToken(
        address underlyingAsset,
        address strikeAsset,
        address oracle,
        uint88 expiryTime,
        bool isCall,
        uint256 strikePrice,
        address controller
    ) public view returns (address qToken, bool exists) {
        bytes memory data = OptionsUtils.getQTokenImmutableArgs(
            optionsDecimals,
            underlyingAsset,
            strikeAsset,
            assetsRegistry,
            oracle,
            expiryTime,
            isCall,
            strikePrice,
            controller
        );

        (qToken, exists) = ClonesWithImmutableArgs.predictDeterministicAddress(
            address(implementation),
            salt,
            data
        );
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
    ) public view returns (uint256 id, bool exists) {
        (address qToken, ) = getQToken(
            underlyingAsset,
            strikeAsset,
            oracle,
            expiryTime,
            isCall,
            strikePrice,
            controller
        );

        id = collateralToken.getCollateralTokenId(qToken, qTokenAsCollateral);

        (qToken, ) = collateralToken.idToInfo(id);

        exists = qToken != address(0);
    }
}
