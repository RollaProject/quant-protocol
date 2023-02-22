// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import {ERC20 as SolmateERC20} from "solmate/src/tokens/ERC20.sol";
import {ERC1155TokenReceiver} from "solmate/src/tokens/ERC1155.sol";
import {Controller, Actions, ActionType, ActionArgs} from "../src/Controller.sol";
import {QuantCalculator} from "../src/QuantCalculator.sol";
import {QToken} from "../src/options/QToken.sol";
import {OptionsFactory} from "../src/options/OptionsFactory.sol";
import {AssetsRegistry} from "../src/options/AssetsRegistry.sol";
import {CollateralToken} from "../src/options/CollateralToken.sol";
import {IPriceRegistry, PriceWithDecimals, PriceStatus} from "../src/interfaces/IPriceRegistry.sol";
import {ActionArgs, ActionType} from "../src/libraries/Actions.sol";

contract ERC20 is SolmateERC20 {
    constructor(string memory _name, string memory _symbol, uint8 _decimals) SolmateERC20(_name, _symbol, _decimals) {}
}

contract ControllerTestBase is Test {
    Controller controller;

    address oracle;
    address oracleRegistry;
    address priceRegistry;
    AssetsRegistry assetsRegistry;
    QToken qTokenXCall;
    QToken qTokenYCall;
    QToken qTokenXPut;
    QToken qTokenPut1400;
    QToken qTokenPut400;
    QToken qTokenCall2000;
    QToken qTokenCall2880;
    QToken qTokenCall3520;
    uint256 cTokenIdXCall;
    uint256 cTokenIdXPut;
    uint256 cTokenIdYCall;
    uint256 cTokenIdPut1400;
    uint256 cTokenIdPut400;
    uint256 cTokenIdCall2000;
    uint256 cTokenIdCall2880;
    uint256 cTokenIdCall3520;
    uint88 expiryTimestamp;
    CollateralToken collateralToken;
    OptionsFactory optionsFactory;
    QuantCalculator quantCalculator;

    address user = 0x31600b6eFf4b91F4ac2dA58Ee3076A6CBD54E6a3;
    address secondaryAccount = 0xf9e01860E3b4e1e7C840b3b2565935D60E2E276A;
    uint256 userPrivKey = uint256(bytes32(0xba03f7828e0845c28f4eafc7991604090c151205f01bd08a0ed7f349e0a1b76e));
    uint256 secondaryAccountPrivKey =
        uint256(bytes32(0x0eeba11b63268770497270ab548c90df2649fc3d9117685bc766cd74e763413c));

    ERC20 BUSD; // 18 decimals
    ERC20 WBNB; // 18 decimals
    ERC20 WBTC; // 8 decimals
    ERC20 WETH; // 18 decimals

    function expireAndSettleOption(address _oracle, uint88 _expiryTime, address _underlying, uint256 _expiryPrice)
        internal
    {
        vm.mockCall(priceRegistry, abi.encodeWithSelector(IPriceRegistry.hasSettlementPrice.selector), abi.encode(true));
        vm.mockCall(
            priceRegistry,
            abi.encodeWithSelector(IPriceRegistry.getOptionPriceStatus.selector, _oracle, _expiryTime, _underlying),
            abi.encode(PriceStatus.SETTLED)
        );
        vm.mockCall(
            priceRegistry,
            abi.encodeWithSelector(
                IPriceRegistry.getSettlementPriceWithDecimals.selector, _oracle, _expiryTime, _underlying
            ),
            abi.encode((_expiryPrice / (10 ** (BUSD.decimals() - 8))), uint8(8))
        );
    }

    function getSignedData(uint256 privKey, bytes32 dataToSign) internal returns (bytes memory signature) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, dataToSign);

        // construct the signature byte array from the individual components
        signature = new bytes(65);
        assembly {
            mstore(add(signature, 0x20), r)
            mstore(add(signature, 0x40), s)
            mstore8(add(signature, 0x60), v)
        }
    }

    function setUp() public virtual {
        string memory protocolName = "Quant Protocol";
        string memory protocolVersion = "1.0.0";
        string memory uri = "https://tokens.rolla.finance/{id}.json";

        oracleRegistry = address(1400);
        priceRegistry = address(1337);
        oracle = address(8545);

        assetsRegistry = new AssetsRegistry();

        BUSD = new ERC20("Binance USD", "BUSD", 18);
        WBNB = new ERC20("Wrapped BNB", "WBNB", 18);
        WBTC = new ERC20("Wrapped BTC", "WBTC", 8);
        WETH = new ERC20("Wrapped Ether", "WETH", 18);

        assetsRegistry.addAssetWithOptionalERC20Methods(address(BUSD));
        assetsRegistry.addAssetWithOptionalERC20Methods(address(WBNB));
        assetsRegistry.addAssetWithOptionalERC20Methods(address(WBTC));
        assetsRegistry.addAssetWithOptionalERC20Methods(address(WETH));

        QToken implementation = new QToken();

        controller = new Controller(
            protocolName,
            protocolVersion,
            uri,
            oracleRegistry,
            address(BUSD),
            priceRegistry,
            address(assetsRegistry),
            implementation
        );

        optionsFactory = OptionsFactory(controller.optionsFactory());

        collateralToken = CollateralToken(controller.collateralToken());

        quantCalculator = QuantCalculator(controller.quantCalculator());

        vm.mockCall(
            oracle,
            abi.encodeWithSelector(bytes4(keccak256(bytes("isValidOption(address,uint88,uint256)")))),
            abi.encode(true)
        );

        vm.mockCall(
            oracleRegistry,
            abi.encodeWithSelector(bytes4(keccak256(bytes("isOracleActive(address)")))),
            abi.encode(true)
        );

        expiryTimestamp = uint88(block.timestamp + 604800);

        address qTokenXCallAddress;
        (qTokenXCallAddress, cTokenIdXCall) =
            optionsFactory.createOption(address(WBNB), oracle, expiryTimestamp, true, 500 ether);
        qTokenXCall = QToken(qTokenXCallAddress);

        address qTokenXPutAddress;
        (qTokenXPutAddress, cTokenIdXPut) =
            optionsFactory.createOption(address(WBNB), oracle, expiryTimestamp, false, 200 ether);
        qTokenXPut = QToken(qTokenXPutAddress);

        address qTokenYCallAddress;
        (qTokenYCallAddress, cTokenIdYCall) =
            optionsFactory.createOption(address(WBTC), oracle, expiryTimestamp, true, 20000 * 10 ** 8);
        qTokenYCall = QToken(qTokenYCallAddress);

        address qTokenPut1400Address;
        (qTokenPut1400Address, cTokenIdPut1400) =
            optionsFactory.createOption(address(WETH), oracle, expiryTimestamp, false, 1400 ether);
        qTokenPut1400 = QToken(qTokenPut1400Address);

        address qTokenPut400Address;
        (qTokenPut400Address, cTokenIdPut400) =
            optionsFactory.createOption(address(WETH), oracle, expiryTimestamp, false, 400 ether);
        qTokenPut400 = QToken(qTokenPut400Address);

        address qTokenCall2000Address;
        (qTokenCall2000Address, cTokenIdCall2000) =
            optionsFactory.createOption(address(WETH), oracle, expiryTimestamp, true, 2000 ether);
        qTokenCall2000 = QToken(qTokenCall2000Address);

        address qTokenCall2880Address;
        (qTokenCall2880Address, cTokenIdCall2880) =
            optionsFactory.createOption(address(WETH), oracle, expiryTimestamp, true, 2880 ether);
        qTokenCall2880 = QToken(qTokenCall2880Address);

        address qTokenCall3520Address;
        (qTokenCall3520Address, cTokenIdCall3520) =
            optionsFactory.createOption(address(WETH), oracle, expiryTimestamp, true, 3520 ether);
        qTokenCall3520 = QToken(qTokenCall3520Address);
    }
}
