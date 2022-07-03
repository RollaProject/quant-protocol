// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import {ERC20 as SolmateERC20} from "solmate/tokens/ERC20.sol";
import {ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";
import {Controller} from "../Controller.sol";
import {QToken} from "../options/QToken.sol";
import {OptionsFactory} from "../options/OptionsFactory.sol";
import {AssetsRegistry} from "../options/AssetsRegistry.sol";
import {CollateralToken} from "../options/CollateralToken.sol";
import {
    IPriceRegistry, PriceWithDecimals
} from "../interfaces/IPriceRegistry.sol";
import {ActionArgs, ActionType} from "../libraries/Actions.sol";

contract ERC20 is SolmateERC20 {
    constructor(string memory _name, string memory _symbol, uint8 _decimals)
        SolmateERC20(_name, _symbol, _decimals)
    {}
}

contract ControllerTest is Test {
    Controller controller;
    address oracleRegistry = address(1400);
    address priceRegistry = address(1337);
    address oracle = address(8545);
    AssetsRegistry assetsRegistry;
    QToken qTokenX;
    uint256 cTokenIdX;
    CollateralToken collateralToken;

    address user = 0x56BD08AEE2bA02b1C46227e58B727d6cb621FB40;

    ERC20 BUSD; // 18 decimals
    ERC20 WBNB; // 18 decimals

    function setUp() public {
        string memory protocolName = "Quant Protocol";
        string memory protocolVersion = "1.0.0";
        string memory uri = "https://tokens.rolla.finance/{id}.json";

        assetsRegistry = new AssetsRegistry();

        BUSD = new ERC20("Binance USD", "BUSD", 18);
        WBNB = new ERC20("Wrapped BNB", "WBNB", 18);

        assetsRegistry.addAssetWithOptionalERC20Methods(address(BUSD));
        assetsRegistry.addAssetWithOptionalERC20Methods(address(WBNB));

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

        OptionsFactory optionsFactory =
            OptionsFactory(controller.optionsFactory());

        collateralToken = CollateralToken(controller.collateralToken());

        vm.mockCall(
            oracle,
            abi.encodeWithSelector(
                bytes4(keccak256(bytes("isValidOption(address,uint88,uint256)")))
            ),
            abi.encode(true)
        );

        vm.mockCall(
            oracleRegistry,
            abi.encodeWithSelector(bytes4(keccak256(bytes("isOracleActive(address)")))),
            abi.encode(true)
        );

        address qTokenXAddress;
        (qTokenXAddress, cTokenIdX) = optionsFactory.createOption(
            address(WBNB), oracle, uint88(block.timestamp + 604800), true, 500 ether
        );
        qTokenX = QToken(qTokenXAddress);

        deal(address(WBNB), user, 1 ether, true);

        vm.startPrank(user);
        WBNB.approve(address(controller), type(uint256).max);
    }

    function testCannotExerciseMoreThanBalance() public {
        uint256 futureTimestamp = block.timestamp + 30 * 24 * 3600; // a month from now

        // skip time to 1 hour past the future/expiry timestamp
        vm.warp(futureTimestamp + 3600);

        vm.mockCall(
            priceRegistry,
            abi.encodeWithSelector(
                bytes4(keccak256(bytes("hasSettlementPrice(address,uint88,address)")))
            ),
            abi.encode(true)
        );

        assertEq(
            IPriceRegistry(priceRegistry).hasSettlementPrice(
                address(BUSD), uint88(futureTimestamp), address(controller)
            ),
            true
        );

        PriceWithDecimals memory settlementPrice =
            PriceWithDecimals(20000000000, 8);

        vm.mockCall(
            priceRegistry,
            abi.encodeWithSelector(
                bytes4(
                    keccak256(bytes("getSettlementPriceWithDecimals(address,uint88,address)"))
                )
            ),
            abi.encode(settlementPrice)
        );

        PriceWithDecimals memory returnedPrice = IPriceRegistry(priceRegistry)
            .getSettlementPriceWithDecimals(
            address(BUSD), uint88(futureTimestamp), address(controller)
        );

        assertEq(returnedPrice.price, settlementPrice.price);
        assertEq(
            uint256(returnedPrice.decimals), uint256(settlementPrice.decimals)
        );
    }

    function testGas_mintOptionsPosition() public {
        controller.mintOptionsPosition(user, address(qTokenX), 1 ether);
    }

    function testCannotPassInvalidActionType() public {
        ActionArgs[] memory args = new ActionArgs[](1);
        args[0] = ActionArgs(
            ActionType.Call,
            address(32),
            address(64),
            address(96),
            uint256(128),
            uint256(160),
            "0xc0"
        );

        uint256 firstArrayArgOffset;
        uint256 actionType;
        uint256 invalidActionType = 10;

        assembly {
            firstArrayArgOffset := mload(add(args, 0x20))
            actionType := mload(firstArrayArgOffset)
        }
        assertEq(actionType, uint256(7));

        assembly {
            mstore(firstArrayArgOffset, invalidActionType)
            actionType := mload(firstArrayArgOffset)
        }
        assertEq(actionType, invalidActionType);

        vm.expectRevert(stdError.enumConversionError);

        controller.operate(args);
    }

    function testCannotNeutralizeMoreThanBalance() public {
        uint256 userQTokenBalance = 1 ether;

        deal(address(qTokenX), user, userQTokenBalance, true);

        assertEq(qTokenX.balanceOf(user), userQTokenBalance);

        vm.expectRevert(stdError.arithmeticError);

        controller.neutralizePosition(cTokenIdX, userQTokenBalance * 2);

        // uint256 userCollateralTokenBalance = 0.5 ether;

        // storage slot for the balanceOf mapping in the CollateralToken contract
        uint256 balanceOfSlot = 0;

        // mapping(address => mapping(uint256 => uint256)) balanceOf;
        bytes32 userCTokenBalanceSlot = keccak256(
            abi.encode(cTokenIdX, keccak256(abi.encode(user, balanceOfSlot)))
        );

        // set the balance of the user for cTokenIdX in the CollateralToken contract so that it's
        // not enough to neutralize a whole option position, while the user's QToken balance is enough
        uint256 userCTokenBalance = userQTokenBalance / 2;
        vm.store(
            address(collateralToken),
            userCTokenBalanceSlot,
            bytes32(userCTokenBalance)
        );

        assertEq(collateralToken.balanceOf(user, cTokenIdX), userCTokenBalance);

        vm.expectRevert(stdError.arithmeticError);

        controller.neutralizePosition(cTokenIdX, userQTokenBalance);
    }
}
