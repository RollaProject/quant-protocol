// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import {OptionsFactory} from "../options/OptionsFactory.sol";
import {CollateralToken} from "../options/CollateralToken.sol";
import {ERC20 as SolmateERC20} from "solmate/src/tokens/ERC20.sol";
import {AssetsRegistry} from "../options/AssetsRegistry.sol";
import {OracleRegistry} from "../pricing/OracleRegistry.sol";
import {ChainlinkOracleManager} from "../pricing/oracle/ChainlinkOracleManager.sol";
import {ProviderOracleManager} from "../pricing/oracle/ProviderOracleManager.sol";
import {PriceRegistry} from "../pricing/PriceRegistry.sol";
import {QToken} from "../options/QToken.sol";
import {OptionsUtils, OPTIONS_DECIMALS} from "../libraries/OptionsUtils.sol";

contract ERC20 is SolmateERC20 {
    constructor(string memory _name, string memory _symbol, uint8 _decimals) SolmateERC20(_name, _symbol, _decimals) {}
}

contract OptionsFactoryTest is Test {
    address deployer = address(this);
    address controller = address(1738);
    address priceRegistry = address(1337);
    address chainlinkOracleManager = address(1600);
    address oracleRegistry = address(1400);

    CollateralToken collateralToken;
    OptionsFactory optionsFactory;
    QToken implementation;
    AssetsRegistry assetsRegistry;

    ERC20 BUSD; // 18 decimals
    ERC20 WBNB; // 18 decimals
    string constant protocolName = "Quant Protocol";
    string constant protocolVersion = "1.0.0";
    string constant uri = "https://tokens.rolla.finance/{id}.json";

    uint256 constant TIMESTAMP = 1655333455;

    function setUp() public {
        // vm.startPrank(deployer);
        vm.warp(TIMESTAMP);

        collateralToken = new CollateralToken(
            protocolName,
            protocolVersion,
            "https://tokens.rolla.finance/{id}.json"
        );

        // Deploy and configure the AssetsRegistry
        assetsRegistry = new AssetsRegistry();

        BUSD = new ERC20("Binance USD", "BUSD", 18);
        WBNB = new ERC20("Wrapped BNB", "WBNB", 18);

        assetsRegistry.addAssetWithOptionalERC20Methods(address(BUSD));
        assetsRegistry.addAssetWithOptionalERC20Methods(address(WBNB));

        implementation = new QToken();

        optionsFactory = new OptionsFactory(
            address(BUSD),
            address(collateralToken),
            controller,
            oracleRegistry,
            address(assetsRegistry),
            implementation
        );

        collateralToken.setOptionsFactory(address(optionsFactory));

        vm.mockCall(
            priceRegistry,
            abi.encodeWithSelector(bytes4(keccak256(bytes("oracleRegistry()")))),
            abi.encode(oracleRegistry)
        );

        vm.mockCall(
            oracleRegistry,
            abi.encodeWithSelector(bytes4(keccak256(bytes("isOracleRegistered(address)")))),
            abi.encode(true)
        );

        vm.mockCall(
            chainlinkOracleManager,
            abi.encodeWithSelector(bytes4(keccak256(bytes("getAssetOracle(address)")))),
            abi.encode(address(BUSD)) // can be any non-zero address
        );

        vm.mockCall(
            chainlinkOracleManager,
            abi.encodeWithSelector(bytes4(keccak256(bytes("isValidOption(address,uint88,uint256)")))),
            abi.encode(true)
        );

        vm.mockCall(
            oracleRegistry,
            abi.encodeWithSelector(bytes4(keccak256(bytes("isOracleActive(address)")))),
            abi.encode(true)
        );
    }

    function testGas_deployOptionsFactory() public {
        new OptionsFactory(
            address(BUSD),
            address(collateralToken),
            controller,
            priceRegistry,
            address(assetsRegistry),
            implementation
        );
    }

    function testGas_create() public {
        optionsFactory.createOption(address(WBNB), chainlinkOracleManager, 2284318798, true, 100000 ether);
    }

    function testCreatedOptionParams(
        string memory underlyingName,
        string memory underlyingSymbol,
        uint8 underlyingDecimals,
        address oracle,
        uint32 expiryTime,
        bool isCall,
        uint256 strikePrice
    ) public {
        vm.mockCall(
            oracle,
            abi.encodeWithSelector(bytes4(keccak256(bytes("getAssetOracle(address)")))),
            abi.encode(address(BUSD)) // can be any non-zero address
        );

        vm.mockCall(
            oracle,
            abi.encodeWithSelector(bytes4(keccak256(bytes("isValidOption(address,uint88,uint256)")))),
            abi.encode(true)
        );

        vm.assume(expiryTime > TIMESTAMP);
        uint256 underlyingNameLength = bytes(underlyingName).length;
        uint256 underlyingSymbolLength = bytes(underlyingSymbol).length;
        vm.assume(underlyingNameLength > 0 && underlyingNameLength <= 15);
        vm.assume(underlyingSymbolLength > 0 && underlyingSymbolLength <= 15);
        vm.assume(strikePrice > 0);

        ERC20 underlying = new ERC20(
            underlyingName,
            underlyingSymbol,
            underlyingDecimals
        );

        assetsRegistry.addAssetWithOptionalERC20Methods(address(underlying));

        (address qTokenAddress,) =
            optionsFactory.createOption(address(underlying), oracle, expiryTime, isCall, strikePrice);

        QToken qToken = QToken(qTokenAddress);

        assertEq(qToken.decimals(), OPTIONS_DECIMALS);
        assertEq(qToken.underlyingAsset(), address(underlying));
        assertEq(qToken.strikeAsset(), address(BUSD));
        assertEq(qToken.oracle(), oracle);
        assertEq(qToken.expiryTime(), expiryTime);
        assertEq(qToken.isCall(), isCall);
        assertEq(qToken.strikePrice(), strikePrice);
        assertEq(qToken.controller(), controller);
    }

    function testCreatedOptionParams() public {
        uint88 expiryTime = 2282899998;
        bool isCall = true;
        uint256 strikePrice = 334 ether;

        (address qTokenAddress, uint256 cTokenId) =
            optionsFactory.createOption(address(WBNB), chainlinkOracleManager, expiryTime, isCall, strikePrice);

        QToken qToken = QToken(qTokenAddress);

        console.log(qToken.name());
        console.log(qToken.symbol());

        assertEq(qToken.decimals(), OPTIONS_DECIMALS);
        assertEq(qToken.underlyingAsset(), address(WBNB));
        assertEq(qToken.strikeAsset(), address(BUSD));
        assertEq(qToken.oracle(), chainlinkOracleManager);
        assertEq(qToken.expiryTime(), expiryTime);
        assertEq(qToken.isCall(), isCall);
        assertEq(qToken.strikePrice(), strikePrice);
        assertEq(qToken.controller(), controller);
    }

    function testGas_deployQTokenImpl() public {
        new QToken();
    }

    function testOptionCreationMultiple() public {
        uint256 strikePrice = 100000;
        uint88 expiryTimestamp = uint88(block.timestamp + 3600);
        bool isCall = true;

        optionsFactory.createOption(address(WBNB), chainlinkOracleManager, expiryTimestamp, isCall, strikePrice);

        optionsFactory.createOption(
            address(WBNB), chainlinkOracleManager, expiryTimestamp + 4800, !isCall, strikePrice + 100000
        );

        optionsFactory.createOption(
            address(WBNB), chainlinkOracleManager, expiryTimestamp + 4800, isCall, strikePrice + 100000
        );

        optionsFactory.createOption(
            address(WBNB), address(chainlinkOracleManager), expiryTimestamp, !isCall, strikePrice
        );
    }

    function testCannotCreateDuplicateOption() public {
        uint256 strikePrice = 100000;
        uint88 expiryTimestamp = uint88(block.timestamp + 3600);
        bool isCall = true;

        optionsFactory.createOption(address(WBNB), chainlinkOracleManager, expiryTimestamp, isCall, strikePrice);

        vm.expectRevert(abi.encodeWithSignature("CreateFail()"));
        optionsFactory.createOption(address(WBNB), chainlinkOracleManager, expiryTimestamp, isCall, strikePrice);
    }

    function testGetAssetProperties(
        string memory underlyingName,
        string memory underlyingSymbol,
        uint8 underlyingDecimals
    ) public {
        vm.assume(bytes(underlyingName).length > 0);
        vm.assume(bytes(underlyingSymbol).length > 0);

        ERC20 underlying = new ERC20(
            underlyingName,
            underlyingSymbol,
            underlyingDecimals
        );

        assetsRegistry.addAssetWithOptionalERC20Methods(address(underlying));

        bytes memory assetProperties = OptionsUtils.getAssetProperties(address(underlying), address(assetsRegistry));

        string memory recoveredName;
        string memory recoveredSymbol;
        uint8 recoveredDecimals;
        bool recoveredIsRegistered;
        assembly ("memory-safe") {
            recoveredName := mload(assetProperties)
            recoveredSymbol := mload(add(assetProperties, 0x20))
            recoveredDecimals := shr(248, shl(248, mload(add(assetProperties, 0x40))))
            recoveredIsRegistered := shr(248, shl(248, mload(add(assetProperties, 0x60))))
        }

        assertEq(underlyingName, recoveredName);
        assertEq(underlyingSymbol, recoveredSymbol);
        assertEq(underlyingDecimals, recoveredDecimals);
        assertEq(true, recoveredIsRegistered);
    }
}
