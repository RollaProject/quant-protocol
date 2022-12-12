// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.16;

import {PriceRegistry} from "../src/pricing/PriceRegistry.sol";
import {OracleRegistry} from "../src/pricing/OracleRegistry.sol";
import {OptionsUtils} from "../src/libraries/OptionsUtils.sol";
import "forge-std/Test.sol";

contract PriceRegistryTest is Test {
    PriceRegistry priceRegistry;
    address oracleRegistry = address(133742);

    // this contract is the oracle since its the price submitter(msg.sender) during tests
    address oracle = address(this);
    address asset = address(343343);

    uint8 immutable strikePriceDecimals = OptionsUtils.STRIKE_PRICE_DECIMALS;

    event PriceStored(
        address indexed _oracle,
        address indexed _asset,
        uint88 indexed _expiryTime,
        uint8 _settlementPriceDecimals,
        uint256 _settlementPrice
    );

    function setUp() public {
        priceRegistry = new PriceRegistry(strikePriceDecimals, oracleRegistry);

        vm.mockCall(
            oracleRegistry, abi.encodeWithSelector(OracleRegistry.isOracleRegistered.selector), abi.encode(true)
        );

        vm.mockCall(oracleRegistry, abi.encodeWithSelector(OracleRegistry.isOracleActive.selector), abi.encode(true));
    }

    function testCanSettlePriceOnlyOnce() public {
        uint88 expiryTime = 1;
        uint256 settlementPrice = 10 ** strikePriceDecimals;

        vm.expectRevert("PriceRegistry: No settlement price has been set");
        priceRegistry.getSettlementPrice(oracle, expiryTime, asset);
        assertEq(priceRegistry.hasSettlementPrice(oracle, expiryTime, asset), false);

        vm.expectEmit(true, true, true, true);
        emit PriceStored(oracle, asset, expiryTime, strikePriceDecimals, settlementPrice);
        priceRegistry.setSettlementPrice(asset, expiryTime, strikePriceDecimals, settlementPrice);

        assertEq(priceRegistry.hasSettlementPrice(oracle, expiryTime, asset), true);
        assertEq(priceRegistry.getSettlementPrice(oracle, expiryTime, asset), settlementPrice);

        vm.expectRevert("PriceRegistry: Settlement price has already been set");
        priceRegistry.setSettlementPrice(asset, expiryTime, strikePriceDecimals, settlementPrice);
    }

    function testCanSettlePriceOnlyOnce(uint88 expiryTime, uint128 _settlementPrice, uint8 settlementPriceDecimals)
        public
    {
        settlementPriceDecimals = uint8(bound(settlementPriceDecimals, 0, 32));
        vm.assume(_settlementPrice > 0);
        vm.warp(expiryTime);

        uint256 settlementPrice = _settlementPrice * 10 ** settlementPriceDecimals;

        vm.expectRevert("PriceRegistry: No settlement price has been set");
        priceRegistry.getSettlementPrice(oracle, expiryTime, asset);
        assertEq(priceRegistry.hasSettlementPrice(oracle, expiryTime, asset), false);

        vm.expectEmit(true, true, true, true);
        emit PriceStored(oracle, asset, expiryTime, settlementPriceDecimals, settlementPrice);
        priceRegistry.setSettlementPrice(asset, expiryTime, settlementPriceDecimals, settlementPrice);

        assertEq(priceRegistry.hasSettlementPrice(oracle, expiryTime, asset), true);
        uint256 storedSettlementPrice = _settlementPrice * 10 ** strikePriceDecimals;
        assertEq(priceRegistry.getSettlementPrice(oracle, expiryTime, asset), storedSettlementPrice);

        vm.expectRevert("PriceRegistry: Settlement price has already been set");
        priceRegistry.setSettlementPrice(asset, expiryTime, settlementPriceDecimals, settlementPrice);
    }
}
