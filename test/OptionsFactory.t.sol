// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {OptionsFactory} from "../src/options/OptionsFactory.sol";
import {CollateralToken} from "../src/options/CollateralToken.sol";
import {ERC20 as SolmateERC20} from "solmate/src/tokens/ERC20.sol";
import {AssetsRegistry} from "../src/options/AssetsRegistry.sol";
import {OracleRegistry} from "../src/pricing/OracleRegistry.sol";
import {ChainlinkOracleManager} from "../src/pricing/oracle/ChainlinkOracleManager.sol";
import {ProviderOracleManager} from "../src/pricing/oracle/ProviderOracleManager.sol";
import {PriceRegistry} from "../src/pricing/PriceRegistry.sol";
import {QToken} from "../src/options/QToken.sol";
import {OptionsUtils, OPTIONS_DECIMALS} from "../src/libraries/OptionsUtils.sol";

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

    error DataSizeLimitExceeded(uint256);

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

        (address qTokenAddress, uint256 cTokenId) =
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

        uint256 expectedCTokenId = collateralToken.getCollateralTokenId(qTokenAddress, address(0));
        assertEq(cTokenId, expectedCTokenId);
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

        uint256 expectedCTokenId = collateralToken.getCollateralTokenId(qTokenAddress, address(0));
        assertEq(cTokenId, expectedCTokenId);
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

    function testGetCollateralToken() public {
        uint88 expiryTime = 2282899998;
        bool isCall = true;
        uint256 strikePrice = 334 ether;
        uint256 cTokenId;
        bool exists;
        address qTokenAddress;

        (address expectedQToken,) =
            optionsFactory.getQToken(address(WBNB), chainlinkOracleManager, expiryTime, isCall, strikePrice);

        uint256 expectedCTokenId = collateralToken.getCollateralTokenId(expectedQToken, address(0));

        (cTokenId, exists) = optionsFactory.getCollateralToken(
            address(WBNB), address(0), chainlinkOracleManager, expiryTime, isCall, strikePrice
        );

        assertEq(exists, false);
        assertEq(cTokenId, expectedCTokenId);

        (qTokenAddress, cTokenId) =
            optionsFactory.createOption(address(WBNB), chainlinkOracleManager, expiryTime, isCall, strikePrice);

        (cTokenId, exists) = optionsFactory.getCollateralToken(
            address(WBNB), address(0), chainlinkOracleManager, expiryTime, isCall, strikePrice
        );

        assertEq(exists, true);
        assertEq(cTokenId, expectedCTokenId);
    }

    function testGetCollateralToken(
        string memory underlyingName,
        string memory underlyingSymbol,
        uint8 underlyingDecimals,
        address oracle,
        uint32 expiryTime,
        bool isCall,
        uint256 strikePrice
    ) public {
        uint256 cTokenId;
        bool exists;
        address qTokenAddress;

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

        (address expectedQToken,) =
            optionsFactory.getQToken(address(underlying), oracle, expiryTime, isCall, strikePrice);

        uint256 expectedCTokenId = collateralToken.getCollateralTokenId(expectedQToken, address(0));

        (cTokenId, exists) =
            optionsFactory.getCollateralToken(address(underlying), address(0), oracle, expiryTime, isCall, strikePrice);

        assertEq(exists, false);
        assertEq(cTokenId, expectedCTokenId);

        (qTokenAddress, cTokenId) =
            optionsFactory.createOption(address(underlying), oracle, expiryTime, isCall, strikePrice);

        (cTokenId, exists) =
            optionsFactory.getCollateralToken(address(underlying), address(0), oracle, expiryTime, isCall, strikePrice);

        assertEq(exists, true);
        assertEq(cTokenId, expectedCTokenId);
    }

    function testGetQToken() public {
        uint88 expiryTime = 2282899998;
        bool isCall = true;
        uint256 strikePrice = 334 ether;
        address expectedQTokenAddress = 0x6AA20d86e076925df46d604CEF9ADE8369a82A7d;
        bool exists;
        address qTokenAddress;

        (qTokenAddress, exists) =
            optionsFactory.getQToken(address(WBNB), chainlinkOracleManager, expiryTime, isCall, strikePrice);

        assertEq(qTokenAddress, expectedQTokenAddress);
        assertEq(exists, false);

        (qTokenAddress,) =
            optionsFactory.createOption(address(WBNB), chainlinkOracleManager, expiryTime, isCall, strikePrice);

        assertEq(qTokenAddress, expectedQTokenAddress);

        (qTokenAddress, exists) =
            optionsFactory.getQToken(address(WBNB), chainlinkOracleManager, expiryTime, isCall, strikePrice);

        assertEq(qTokenAddress, expectedQTokenAddress);
        assertEq(exists, true);
    }

    function testCannotCreateExpiredOption() public {
        uint88 expiryTime = 2282899998;
        bool isCall = true;
        uint256 strikePrice = 334 ether;

        vm.warp(expiryTime);
        vm.expectRevert("OptionsFactory: given expiry time is in the past");
        optionsFactory.createOption(address(WBNB), chainlinkOracleManager, expiryTime, isCall, strikePrice);
    }

    function testCannotCreateExpiredOption(
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

        expiryTime = uint32(bound(expiryTime, 0, TIMESTAMP + 1));
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

        vm.expectRevert("OptionsFactory: given expiry time is in the past");

        optionsFactory.createOption(address(underlying), oracle, expiryTime, isCall, strikePrice);
    }

    function testCannotCreateOptionWithoutOracleSupportForUnderlying() public {
        uint88 expiryTime = 2282899998;
        bool isCall = true;
        uint256 strikePrice = 334 ether;

        vm.mockCall(
            chainlinkOracleManager,
            abi.encodeWithSelector(bytes4(keccak256(bytes("isValidOption(address,uint88,uint256)")))),
            abi.encode(false)
        );

        vm.expectRevert("OptionsFactory: Oracle doesn't support the given option");
        optionsFactory.createOption(address(WBNB), chainlinkOracleManager, expiryTime, isCall, strikePrice);
    }

    function testCannotCreateOptionWithoutOracleSupportForUnderlying(
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
            abi.encode(false)
        );

        expiryTime = uint32(bound(expiryTime, TIMESTAMP + 1, type(uint32).max));
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

        vm.expectRevert("OptionsFactory: Oracle doesn't support the given option");

        optionsFactory.createOption(address(underlying), oracle, expiryTime, isCall, strikePrice);
    }

    function testCannotCreateOptionWithInactiveOracle() public {
        uint88 expiryTime = 2282899998;
        bool isCall = true;
        uint256 strikePrice = 334 ether;

        vm.mockCall(
            oracleRegistry,
            abi.encodeWithSelector(bytes4(keccak256(bytes("isOracleActive(address)")))),
            abi.encode(false)
        );

        vm.expectRevert("OptionsFactory: Oracle is not active in the OracleRegistry");

        optionsFactory.createOption(address(WBNB), chainlinkOracleManager, expiryTime, isCall, strikePrice);
    }

    // fuzz test for testCannotCreateOptionWithInactiveOracle
    function testCannotCreateOptionWithInactiveOracle(
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

        vm.mockCall(
            oracleRegistry,
            abi.encodeWithSelector(bytes4(keccak256(bytes("isOracleActive(address)")))),
            abi.encode(false)
        );

        expiryTime = uint32(bound(expiryTime, TIMESTAMP + 1, type(uint32).max));
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

        vm.expectRevert("OptionsFactory: Oracle is not active in the OracleRegistry");

        optionsFactory.createOption(address(underlying), oracle, expiryTime, isCall, strikePrice);
    }

    function testCannotCreateOptionWithZeroStrike() public {
        uint88 expiryTime = 2282899998;
        bool isCall = true;
        uint256 strikePrice = 0;

        vm.expectRevert("strike can't be 0");

        optionsFactory.createOption(address(WBNB), chainlinkOracleManager, expiryTime, isCall, strikePrice);
    }

    // fuzz test for testCannotCreateOptionWithZeroStrike
    function testCannotCreateOptionWithZeroStrike(
        string memory underlyingName,
        string memory underlyingSymbol,
        uint8 underlyingDecimals,
        address oracle,
        uint32 expiryTime,
        bool isCall
    ) public {
        uint256 strikePrice = 0;

        expiryTime = uint32(bound(expiryTime, TIMESTAMP + 1, type(uint32).max));
        uint256 underlyingNameLength = bytes(underlyingName).length;
        uint256 underlyingSymbolLength = bytes(underlyingSymbol).length;
        vm.assume(underlyingNameLength > 0 && underlyingNameLength <= 15);
        vm.assume(underlyingSymbolLength > 0 && underlyingSymbolLength <= 15);

        ERC20 underlying = new ERC20(
            underlyingName,
            underlyingSymbol,
            underlyingDecimals
        );

        assetsRegistry.addAssetWithOptionalERC20Methods(address(underlying));

        vm.mockCall(
            oracle,
            abi.encodeWithSelector(bytes4(keccak256(bytes("getAssetOracle(address)"))), address(underlying)),
            abi.encode(address(BUSD)) // can be any non-zero address
        );

        vm.mockCall(
            oracle,
            abi.encodeWithSelector(
                bytes4(keccak256(bytes("isValidOption(address,uint88,uint256)"))),
                address(underlying),
                expiryTime,
                strikePrice
            ),
            abi.encode(true)
        );

        vm.expectRevert("strike can't be 0");

        optionsFactory.createOption(address(underlying), oracle, expiryTime, isCall, strikePrice);
    }

    function testCannotCreateOptionWithUnregisteredUnderlying() public {
        uint88 expiryTime = 2282899998;
        bool isCall = true;
        uint256 strikePrice = 334 ether;

        ERC20 underlying = new ERC20("Some Token", "ST", 18);

        vm.expectRevert("underlying not in the registry");

        optionsFactory.createOption(address(underlying), chainlinkOracleManager, expiryTime, isCall, strikePrice);
    }

    // fuzz test for testCannotCreateOptionWithUnregisteredUnderlying
    function testCannotCreateOptionWithUnregisteredUnderlying(
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

        expiryTime = uint32(bound(expiryTime, TIMESTAMP + 1, type(uint32).max));
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

        vm.expectRevert("underlying not in the registry");

        optionsFactory.createOption(address(underlying), oracle, expiryTime, isCall, strikePrice);
    }

    function testCannotCreateOptionWithNameGreaterThan127Bytes() public {
        uint88 expiryTime = 3555446400;
        uint256 strikePrice = 10000000000000000000000000000000000000000000000000000000000000000000000000001;
        bool isCall = true;
        uint8 decimals = 0;
        string memory name = string(bytes("0x00000000000000000000000000000000000000000000000000000000000000"));
        string memory symbol = string(bytes("0x00000000000000000000000000000000000000000000000000000000000000"));

        ERC20 underlying = new ERC20(name, symbol, decimals);

        assetsRegistry.addAssetWithOptionalERC20Methods(address(underlying));

        vm.expectRevert(abi.encodeWithSelector(DataSizeLimitExceeded.selector, 161));
        optionsFactory.createOption(address(underlying), chainlinkOracleManager, expiryTime, isCall, strikePrice);
    }
}
