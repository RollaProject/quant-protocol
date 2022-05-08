// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import {OptionsFactory} from "../options/OptionsFactory.sol";
import {CollateralToken} from "../options/CollateralToken.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {BEP20} from "../mocks/BEP20.sol";
import {AssetsRegistry} from "../options/AssetsRegistry.sol";
import {OracleRegistry} from "../pricing/OracleRegistry.sol";
import {ChainlinkOracleManager} from "../pricing/oracle/ChainlinkOracleManager.sol";
import {ProviderOracleManager} from "../pricing/oracle/ProviderOracleManager.sol";
import {PriceRegistry} from "../pricing/PriceRegistry.sol";
import {QToken} from "../options/QToken.sol";

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

    BEP20 BUSD; // 18 decimals
    BEP20 WBNB; // 18 decimals
    string constant protocolName = "Quant Protocol";
    string constant protocolVersion = "1.0.0";

    function setUp() public {
        // vm.startPrank(deployer);

        collateralToken = new CollateralToken(
            protocolName,
            protocolVersion,
            "https://tokens.rolla.finance/{id}.json"
        );

        // Deploy and configure the AssetsRegistry
        assetsRegistry = new AssetsRegistry();

        uint256 unscaledInitialSupply = 10000000;
        BUSD = new BEP20(
            "Binance USD",
            "BUSD",
            18,
            unscaledInitialSupply * 10**18
        );
        WBNB = new BEP20(
            "Wrapped BNB",
            "WBNB",
            18,
            unscaledInitialSupply * 10**18
        );

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

        // Deploy and configure the ChainlinkOracleManager
        // chainlinkOracleManager = new ChainlinkOracleManager(
        //     address(quantConfig),
        //     BUSD.decimals(),
        //     fallbackPeriod
        // );
        // quantConfig.setProtocolAddress(
        //     keccak256("chainlinkOracleManager"),
        //     address(chainlinkOracleManager)
        // );

        vm.mockCall(
            priceRegistry,
            abi.encodeWithSelector(
                bytes4(keccak256(bytes("oracleRegistry()")))
            ),
            abi.encode(oracleRegistry)
        );

        vm.mockCall(
            oracleRegistry,
            abi.encodeWithSelector(
                bytes4(keccak256(bytes("isOracleRegistered(address)")))
            ),
            abi.encode(true)
        );

        vm.mockCall(
            chainlinkOracleManager,
            abi.encodeWithSelector(
                bytes4(keccak256(bytes("getAssetOracle(address)")))
            ),
            abi.encode(address(BUSD)) // can be any non-zero address
        );

        vm.mockCall(
            chainlinkOracleManager,
            abi.encodeWithSelector(
                bytes4(
                    keccak256(bytes("isValidOption(address,uint88,uint256)"))
                )
            ),
            abi.encode(true)
        );

        vm.mockCall(
            oracleRegistry,
            abi.encodeWithSelector(
                bytes4(keccak256(bytes("isOracleActive(address)")))
            ),
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
        optionsFactory.createOption(
            address(WBNB),
            chainlinkOracleManager,
            2282899998,
            true,
            100000 ether
        );
    }

    function testCreatedOptionParams() public {
        uint88 expiryTime = 2282899998;
        bool isCall = true;
        uint256 strikePrice = 334 ether;

        (address qTokenAddress, uint256 cTokenId) = optionsFactory.createOption(
            address(WBNB),
            chainlinkOracleManager,
            expiryTime,
            isCall,
            strikePrice
        );

        QToken qToken = QToken(qTokenAddress);

        console.log(qToken.name());
        console.log(qToken.symbol());

        assertEq(qToken.decimals(), optionsFactory.optionsDecimals());
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

    // function testOption

    function testOptionCreationMultiple() public // uint256 strikePrice,
    // uint256 expiryTimestamp,
    // bool isCall
    {
        // vm.assume(strikePrice > 0);
        // vm.assume(expiryTimestamp > block.timestamp);

        uint256 strikePrice = 100000;
        uint88 expiryTimestamp = uint88(block.timestamp + 3600);
        bool isCall = true;

        optionsFactory.createOption(
            address(WBNB),
            chainlinkOracleManager,
            expiryTimestamp,
            isCall,
            strikePrice
        );

        optionsFactory.createOption(
            address(WBNB),
            chainlinkOracleManager,
            expiryTimestamp + 4800,
            !isCall,
            strikePrice + 100000
        );

        // optionsFactory.createOption(
        //     address(WBNB),
        //     chainlinkOracleManager,
        //     expiryTimestamp + 4800,
        //     isCall,
        //     strikePrice + 100000
        // );

        // optionsFactory.createOption(
        //     address(WBNB),
        //     address(chainlinkOracleManager),
        //     expiryTimestamp,
        //     !isCall,
        //     strikePrice
        // );
    }
}
