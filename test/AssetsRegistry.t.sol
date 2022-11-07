// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../src/options/AssetsRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20WithDecimals is ERC20 {
    event AssetAdded(address indexed underlying, string name, string symbol, uint8 decimals);

    uint8 private _decimals;

    constructor(string memory _name, string memory _symbol, uint8 decimals_) ERC20(_name, _symbol) {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}

contract SimpleERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }
}

contract AssetsRegistryTest is Test {
    AssetsRegistry public assetsRegistry;

    address public quantConfig;

    event AssetAdded(address indexed underlying, string name, string symbol, uint8 decimals);

    function setUp() public {
        assetsRegistry = new AssetsRegistry();
    }

    function testAddAssetWithOptionalERC20Methods() public {
        string memory name = "BTCB Token";
        string memory symbol = "BTCB";
        uint8 decimals = 18;

        ERC20WithDecimals asset = new ERC20WithDecimals(name, symbol, decimals);

        assertEq(asset.name(), name);
        assertEq(asset.symbol(), symbol);
        assertEq(uint256(asset.decimals()), uint256(decimals));

        vm.expectEmit(true, false, false, true);

        emit AssetAdded(address(asset), name, symbol, decimals);

        assetsRegistry.addAssetWithOptionalERC20Methods(address(asset));

        address registeredAsset = assetsRegistry.registeredAssets(0);
        assertEq(registeredAsset, address(asset));

        (string memory registeredName, string memory registeredSymbol, uint8 registeredDecimals, bool isRegistered) =
            assetsRegistry.assetProperties(registeredAsset);

        assertEq(registeredName, name);
        assertEq(registeredSymbol, symbol);
        assertEq(uint256(registeredDecimals), uint256(decimals));
        assert(isRegistered);
    }

    function testCannotAddAssetWithoutOptionalERC20Methods(string memory name, string memory symbol) public {
        SimpleERC20 asset = new SimpleERC20(name, symbol);

        // Should revert when trying to call asset.name()
        vm.expectRevert(bytes(""));

        assetsRegistry.addAssetWithOptionalERC20Methods(address(asset));
    }

    function testCannotAddAssetAsNotRegistryOwner() public {
        string memory name = "BUSD Token";
        string memory symbol = "BUSD";
        uint8 decimals = 18;

        ERC20WithDecimals asset = new ERC20WithDecimals(name, symbol, decimals);

        vm.prank(address(1337));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        assetsRegistry.addAssetWithOptionalERC20Methods(address(asset));
    }

    function testCannotAddSameAssetTwice() public {
        string memory name = "Wrapped Ether";
        string memory symbol = "WETH";
        uint8 decimals = 18;

        ERC20WithDecimals asset = new ERC20WithDecimals(name, symbol, decimals);

        assetsRegistry.addAssetWithOptionalERC20Methods(address(asset));

        vm.expectRevert(bytes("AssetsRegistry: asset already added"));

        assetsRegistry.addAssetWithOptionalERC20Methods(address(asset));
    }

    function testAddAsset(string memory name, string memory symbol, uint8 decimals) public {
        vm.assume(bytes(symbol).length != 0);
        vm.assume(bytes(name).length != 0);

        SimpleERC20 asset = new SimpleERC20(name, symbol);

        assetsRegistry.addAsset(address(asset), name, symbol, decimals);

        address registeredAsset = assetsRegistry.registeredAssets(0);
        assertEq(registeredAsset, address(asset));

        (string memory registeredName, string memory registeredSymbol, uint8 registeredDecimals, bool isRegistered) =
            assetsRegistry.assetProperties(registeredAsset);

        assertEq(registeredName, name);
        assertEq(registeredSymbol, symbol);
        assertEq(uint256(registeredDecimals), uint256(decimals));
        assert(isRegistered);
        assertEq(assetsRegistry.getAssetsLength(), 1);
    }

    function testCannotAddAssetWithEmptyAddress(string memory name, string memory symbol, uint8 decimals) public {
        vm.expectRevert("AssetsRegistry: invalid underlying address");
        assetsRegistry.addAsset(address(0), name, symbol, decimals);
    }

    function testCannotAddAssetWithEmptyName(address asset, string memory symbol, uint8 decimals) public {
        vm.assume(asset != address(0));
        vm.expectRevert("AssetsRegistry: invalid name");
        assetsRegistry.addAsset(asset, "", symbol, decimals);

        ERC20WithDecimals assetWithOptionalMethods = new ERC20WithDecimals("", symbol, decimals);
        vm.expectRevert("AssetsRegistry: invalid empty name");
        assetsRegistry.addAssetWithOptionalERC20Methods(address(assetWithOptionalMethods));
    }

    function testCannotAddAssetWithEmptySymbol(address asset, string memory name, uint8 decimals) public {
        vm.assume(asset != address(0));
        vm.assume(bytes(name).length != 0);
        vm.expectRevert("AssetsRegistry: invalid symbol");
        assetsRegistry.addAsset(asset, name, "", decimals);

        ERC20WithDecimals assetWithOptionalMethods = new ERC20WithDecimals(name, "", decimals);
        vm.expectRevert("AssetsRegistry: invalid empty symbol");
        assetsRegistry.addAssetWithOptionalERC20Methods(address(assetWithOptionalMethods));
    }

    function testEmitAssetAddedEvent(address asset, string memory name, string memory symbol, uint8 decimals) public {
        vm.assume(asset != address(0));
        vm.assume(bytes(name).length != 0);
        vm.assume(bytes(symbol).length != 0);

        vm.expectEmit(true, false, false, true, address(assetsRegistry));
        emit AssetAdded(asset, name, symbol, decimals);
        assetsRegistry.addAsset(asset, name, symbol, decimals);
    }
}
