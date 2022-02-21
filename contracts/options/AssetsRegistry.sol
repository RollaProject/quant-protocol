// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IQuantConfig.sol";
import "../interfaces/IAssetsRegistry.sol";

contract AssetsRegistry is IAssetsRegistry {
    struct AssetProperties {
        string name;
        string symbol;
        uint8 decimals;
        uint256 quantityTickSize;
    }

    struct OptionalERC20Methods {
        bool isNameImplemented;
        bool isSymbolImplemented;
        bool isDecimalsImplemented;
    }

    IQuantConfig private _quantConfig;

    mapping(address => AssetProperties) public override assetProperties;

    address[] public override registeredAssets;

    modifier validAsset(address _underlying) {
        require(
            _quantConfig.hasRole(
                _quantConfig.quantRoles("ASSETS_REGISTRY_MANAGER_ROLE"),
                msg.sender
            ),
            "AssetsRegistry: only asset registry managers can add assets"
        );

        require(
            bytes(assetProperties[_underlying].symbol).length == 0,
            "AssetsRegistry: asset already added"
        );

        _;
    }

    constructor(address quantConfig_) {
        require(
            quantConfig_ != address(0),
            "AssetsRegistry: invalid QuantConfig address"
        );

        _quantConfig = IQuantConfig(quantConfig_);
    }

    function addAsset(
        address _underlying,
        string calldata _name,
        string calldata _symbol,
        uint8 _decimals,
        uint256 _quantityTickSize
    ) external override validAsset(_underlying) {
        assetProperties[_underlying] = AssetProperties(
            _name,
            _symbol,
            _decimals,
            _quantityTickSize
        );

        registeredAssets.push(_underlying);

        emit AssetAdded(
            _underlying,
            _name,
            _symbol,
            _decimals,
            _quantityTickSize
        );

        emit QuantityTickSizeUpdated(_underlying, 0, _quantityTickSize);
    }

    function addAssetWithOptionalERC20Methods(
        address _underlying,
        uint256 _quantityTickSize
    ) external override validAsset(_underlying) {
        string memory name = ERC20(_underlying).name();
        require(bytes(name).length > 0, "AssetsRegistry: invalid empty name");

        string memory symbol = ERC20(_underlying).symbol();
        require(
            bytes(symbol).length > 0,
            "AssetsRegistry: invalid empty symbol"
        );

        uint8 decimals = ERC20(_underlying).decimals();
        require(decimals > 0, "AssetsRegistry: invalid zero decimals");

        assetProperties[_underlying] = AssetProperties(
            name,
            symbol,
            decimals,
            _quantityTickSize
        );

        registeredAssets.push(_underlying);

        emit AssetAdded(_underlying, name, symbol, decimals, _quantityTickSize);

        emit QuantityTickSizeUpdated(_underlying, 0, _quantityTickSize);
    }

    function setQuantityTickSize(address _underlying, uint256 _quantityTickSize)
        external
        override
    {
        require(
            _quantConfig.hasRole(
                _quantConfig.quantRoles("ASSETS_REGISTRY_MANAGER_ROLE"),
                msg.sender
            ),
            "AssetsRegistry: only asset registry managers can change assets' quantity tick sizes"
        );

        require(
            bytes(assetProperties[_underlying].symbol).length != 0,
            "AssetsRegistry: asset not in the registry yet"
        );

        AssetProperties storage underlyingProperties =
            assetProperties[_underlying];

        emit QuantityTickSizeUpdated(
            _underlying,
            underlyingProperties.quantityTickSize,
            _quantityTickSize
        );

        underlyingProperties.quantityTickSize = _quantityTickSize;
    }

    function getAssetsLength() external view override returns (uint256) {
        return registeredAssets.length;
    }

    function _resultBytesToString(bytes memory result)
        internal
        pure
        returns (string memory stringResult)
    {
        uint8 startPos = 62;
        // skip empty bytes and special UTF-8 characters and escape sequences before '!'(0x21)
        while (result[startPos] == 0 || uint8(result[startPos]) < 21) {
            startPos++;
        }
        uint8 endPos = startPos;
        while (result[endPos] != 0) {
            endPos++;
        }

        bytes memory resultBytes = new bytes(endPos - startPos);
        for (uint8 i = startPos; i < endPos; i++) {
            resultBytes[i - startPos] = result[i];
        }

        require(resultBytes.length > 0, "AssetsRegistry: invalid result bytes");

        stringResult = string(resultBytes);
    }
}
