// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../QuantConfig.sol";
import "../interfaces/IAssetsRegistry.sol";

contract AssetsRegistry is IAssetsRegistry {
    struct AssetProperties {
        string name;
        string symbol;
        uint8 decimals;
    }

    QuantConfig private _quantConfig;

    mapping(address => AssetProperties) public assetProperties;

    event AssetAdded(
        address indexed underlying,
        string name,
        string symbol,
        uint8 decimals
    );

    constructor(address quantConfig_) {
        _quantConfig = QuantConfig(quantConfig_);
    }

    //TODO: Method in here to get a list of assets

    function addAsset(
        address _underlying,
        string calldata _name,
        string calldata _symbol,
        uint8 _decimals
    ) external override {
        require(
            _quantConfig.hasRole(
                _quantConfig.ASSET_REGISTRY_MANAGER_ROLE(),
                msg.sender
            ),
            "AssetsRegistry: only asset registry managers can add assets"
        );

        require(
            bytes(assetProperties[_underlying].symbol).length == 0,
            "AssetsRegistry: asset already added"
        );

        string memory name;
        try ERC20(_underlying).name() returns (string memory contractName) {
            name = contractName;
        } catch {
            name = _name;
        }

        string memory symbol;
        try ERC20(_underlying).symbol() returns (string memory contractSymbol) {
            symbol = contractSymbol;
        } catch {
            symbol = _symbol;
        }

        uint8 decimals;
        try ERC20(_underlying).decimals() returns (uint8 contractDecimals) {
            decimals = contractDecimals;
        } catch {
            decimals = _decimals;
        }

        assetProperties[_underlying] = AssetProperties(name, symbol, decimals);

        emit AssetAdded(_underlying, name, symbol, decimals);
    }
}
