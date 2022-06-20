// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import {Controller} from "../Controller.sol";
import {BEP20} from "../mocks/BEP20.sol";
import {QToken} from "../options/QToken.sol";
import {AssetsRegistry} from "../options/AssetsRegistry.sol";
import {IPriceRegistry, PriceWithDecimals} from "../interfaces/IPriceRegistry.sol";

contract ControllerTest is Test {
    Controller controller;
    address oracleRegistry = address(1400);
    address priceRegistry = address(1337);
    AssetsRegistry assetsRegistry;

    BEP20 BUSD; // 18 decimals
    BEP20 WBNB; // 18 decimals

    function setUp() public {
        string memory protocolName = "Quant Protocol";
        string memory protocolVersion = "1.0.0";
        string memory uri = "https://tokens.rolla.finance/{id}.json";

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
    }

    function testCannotExerciseMoreThanBalance() public {
        uint256 futureTimestamp = block.timestamp + 30 * 24 * 3600; // a month from now

        // skip time to 1 hour past the future/expiry timestamp
        vm.warp(futureTimestamp + 3600);

        vm.mockCall(
            priceRegistry,
            abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        bytes("hasSettlementPrice(address,uint88,address)")
                    )
                )
            ),
            abi.encode(true)
        );

        assertEq(
            IPriceRegistry(priceRegistry).hasSettlementPrice(
                address(BUSD),
                uint88(futureTimestamp),
                address(controller)
            ),
            true
        );

        PriceWithDecimals memory settlementPrice = PriceWithDecimals(
            20000000000,
            8
        );

        vm.mockCall(
            priceRegistry,
            abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        bytes(
                            "getSettlementPriceWithDecimals(address,uint88,address)"
                        )
                    )
                )
            ),
            abi.encode(settlementPrice)
        );

        PriceWithDecimals memory returnedPrice = IPriceRegistry(priceRegistry)
            .getSettlementPriceWithDecimals(
                address(BUSD),
                uint88(futureTimestamp),
                address(controller)
            );

        assertEq(returnedPrice.price, settlementPrice.price);
        assertEq(
            uint256(returnedPrice.decimals),
            uint256(settlementPrice.decimals)
        );
    }
}
