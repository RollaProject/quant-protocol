// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IAssetsRegistry.sol";

/// @title For managing assets supported as underlying for options in the Quant Protocol
/// @author Rolla
contract AssetsRegistry is Ownable, IAssetsRegistry {
    struct AssetProperties {
        string name;
        string symbol;
        uint8 decimals;
        bool isRegistered;
    }

    /// @inheritdoc IAssetsRegistry
    mapping(address => AssetProperties) public override assetProperties;

    /// @inheritdoc IAssetsRegistry
    address[] public override registeredAssets;

    /// @dev Checks that the asset had not been added before.
    modifier validAsset(address _underlying) {
        require(
            !assetProperties[_underlying].isRegistered,
            "AssetsRegistry: asset already added"
        );

        _;
    }

    /// @inheritdoc IAssetsRegistry
    function addAsset(
        address _underlying,
        string calldata _name,
        string calldata _symbol,
        uint8 _decimals
    )
        external
        override
        onlyOwner
        validAsset(_underlying)
    {
        require(
            _underlying != address(0), "AssetsRegistry: invalid underlying address"
        );
        require(bytes(_name).length > 0, "AssetsRegistry: invalid name");
        require(bytes(_symbol).length > 0, "AssetsRegistry: invalid symbol");

        assetProperties[_underlying] =
            AssetProperties(_name, _symbol, _decimals, true);

        registeredAssets.push(_underlying);

        emit AssetAdded(_underlying, _name, _symbol, _decimals);
    }

    /// @inheritdoc IAssetsRegistry
    function addAssetWithOptionalERC20Methods(address _underlying)
        external
        override
        onlyOwner
        validAsset(_underlying)
    {
        string memory name = ERC20(_underlying).name();
        require(bytes(name).length > 0, "AssetsRegistry: invalid empty name");

        string memory symbol = ERC20(_underlying).symbol();
        require(
            bytes(symbol).length > 0, "AssetsRegistry: invalid empty symbol"
        );

        uint8 decimals = ERC20(_underlying).decimals();

        assetProperties[_underlying] =
            AssetProperties(name, symbol, decimals, true);

        registeredAssets.push(_underlying);

        emit AssetAdded(_underlying, name, symbol, decimals);
    }

    /// @inheritdoc IAssetsRegistry
    function getAssetsLength() external view override returns (uint256) {
        return registeredAssets.length;
    }
}