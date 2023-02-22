// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.18;

import {PriceRegistry, PriceWithDecimals, PriceStatus} from "../src/pricing/PriceRegistry.sol";
import {OracleRegistry} from "../src/pricing/OracleRegistry.sol";
import {OptionsUtils} from "../src/libraries/OptionsUtils.sol";
import "forge-std/Test.sol";

contract PriceRegistryTest is Test {
    PriceRegistry priceRegistry;
    address oracleRegistry = address(133742);

    // this contract is the oracle since its the price submitter(msg.sender) during tests
    address oracle = address(this);

    uint8 immutable strikePriceDecimals = OptionsUtils.STRIKE_PRICE_DECIMALS;

    uint32 immutable disputePeriod = 2 hours;

    bytes32 immutable disputePeriodSlot = bytes32(uint256(0));

    uint256 immutable disputerRole = 1 << 0;

    event PriceStored(
        address indexed _oracle,
        address indexed _asset,
        uint88 indexed _expiryTime,
        uint8 _settlementPriceDecimals,
        uint256 _settlementPrice
    );

    event DisputePeriodSet(uint32 _disputePeriod);

    error Unauthorized();

    function setUp() public {
        priceRegistry = new PriceRegistry(strikePriceDecimals, disputePeriod, oracleRegistry);

        vm.mockCall(
            oracleRegistry, abi.encodeWithSelector(OracleRegistry.isOracleRegistered.selector), abi.encode(true)
        );

        vm.mockCall(oracleRegistry, abi.encodeWithSelector(OracleRegistry.isOracleActive.selector), abi.encode(true));
    }

    function testCanSettlePriceOnlyOnce() public {
        uint88 expiryTime = 2;
        uint256 settlementPrice = 10 ** strikePriceDecimals;
        address asset = address(343343);

        assertEq(uint256(priceRegistry.getOptionPriceStatus(oracle, expiryTime, asset)), uint256(PriceStatus.ACTIVE));

        vm.warp(expiryTime);

        vm.expectRevert("PriceRegistry: No settlement price has been set");
        priceRegistry.getSettlementPrice(oracle, expiryTime, asset);
        vm.expectRevert("PriceRegistry: No settlement price has been set");
        priceRegistry.getSettlementPriceWithDecimals(oracle, expiryTime, asset);
        assertEq(priceRegistry.hasSettlementPrice(oracle, expiryTime, asset), false);
        assertEq(
            uint256(priceRegistry.getOptionPriceStatus(oracle, expiryTime, asset)), uint256(PriceStatus.DISPUTABLE)
        );

        vm.warp(expiryTime + disputePeriod + 1);

        assertEq(
            uint256(priceRegistry.getOptionPriceStatus(oracle, expiryTime, asset)),
            uint256(PriceStatus.AWAITING_SETTLEMENT_PRICE)
        );

        vm.expectEmit(true, true, true, true);
        emit PriceStored(oracle, asset, expiryTime, strikePriceDecimals, settlementPrice);
        priceRegistry.setSettlementPrice(asset, expiryTime, strikePriceDecimals, settlementPrice);

        assertEq(priceRegistry.hasSettlementPrice(oracle, expiryTime, asset), true);
        assertEq(uint256(priceRegistry.getOptionPriceStatus(oracle, expiryTime, asset)), uint256(PriceStatus.SETTLED));
        assertEq(priceRegistry.getSettlementPrice(oracle, expiryTime, asset), settlementPrice);

        PriceWithDecimals memory settlementPriceWithDecimals =
            priceRegistry.getSettlementPriceWithDecimals(oracle, expiryTime, asset);

        assertEq(settlementPriceWithDecimals.price, settlementPrice);
        assertEq(settlementPriceWithDecimals.decimals, strikePriceDecimals);

        vm.expectRevert("PriceRegistry: Settlement price has already been set");
        priceRegistry.setSettlementPrice(asset, expiryTime, strikePriceDecimals, settlementPrice);
    }

    function testCanSettlePriceOnlyOnce(
        address asset,
        uint88 expiryTime,
        uint128 _settlementPrice,
        uint8 settlementPriceDecimals
    ) public {
        settlementPriceDecimals = uint8(bound(settlementPriceDecimals, 0, 32));
        expiryTime = uint88(bound(expiryTime, block.timestamp + 1, type(uint88).max - disputePeriod));
        vm.assume(_settlementPrice > 0);
        uint256 settlementPrice = _settlementPrice * 10 ** settlementPriceDecimals;

        assertEq(uint256(priceRegistry.getOptionPriceStatus(oracle, expiryTime, asset)), uint256(PriceStatus.ACTIVE));

        vm.warp(expiryTime);

        vm.expectRevert("PriceRegistry: No settlement price has been set");
        priceRegistry.getSettlementPrice(oracle, expiryTime, asset);
        vm.expectRevert("PriceRegistry: No settlement price has been set");
        priceRegistry.getSettlementPriceWithDecimals(oracle, expiryTime, asset);
        assertEq(priceRegistry.hasSettlementPrice(oracle, expiryTime, asset), false);
        assertEq(
            uint256(priceRegistry.getOptionPriceStatus(oracle, expiryTime, asset)), uint256(PriceStatus.DISPUTABLE)
        );

        vm.warp(expiryTime + disputePeriod + 1);

        assertEq(
            uint256(priceRegistry.getOptionPriceStatus(oracle, expiryTime, asset)),
            uint256(PriceStatus.AWAITING_SETTLEMENT_PRICE)
        );

        vm.expectEmit(true, true, true, true);
        emit PriceStored(oracle, asset, expiryTime, settlementPriceDecimals, settlementPrice);
        priceRegistry.setSettlementPrice(asset, expiryTime, settlementPriceDecimals, settlementPrice);

        assertEq(priceRegistry.hasSettlementPrice(oracle, expiryTime, asset), true);
        assertEq(uint256(priceRegistry.getOptionPriceStatus(oracle, expiryTime, asset)), uint256(PriceStatus.SETTLED));

        uint256 storedSettlementPrice = _settlementPrice * 10 ** strikePriceDecimals;
        assertEq(priceRegistry.getSettlementPrice(oracle, expiryTime, asset), storedSettlementPrice);

        PriceWithDecimals memory settlementPriceWithDecimals =
            priceRegistry.getSettlementPriceWithDecimals(oracle, expiryTime, asset);

        assertEq(settlementPriceWithDecimals.price, settlementPrice);
        assertEq(settlementPriceWithDecimals.decimals, settlementPriceDecimals);

        vm.expectRevert("PriceRegistry: Settlement price has already been set");
        priceRegistry.setSettlementPrice(asset, expiryTime, settlementPriceDecimals, settlementPrice);
    }

    function testCannotSettlePriceWithUnauthorizedAccount(
        address sender,
        address asset,
        uint88 expiryTime,
        uint128 _settlementPrice,
        uint8 settlementPriceDecimals
    ) public {
        vm.assume(sender != address(0) && sender != oracle);
        settlementPriceDecimals = uint8(bound(settlementPriceDecimals, 0, 32));
        vm.assume(_settlementPrice > 0);
        vm.warp(expiryTime);

        uint256 settlementPrice = _settlementPrice * 10 ** settlementPriceDecimals;

        vm.mockCall(
            oracleRegistry,
            abi.encodeWithSelector(OracleRegistry.isOracleRegistered.selector, sender),
            abi.encode(false)
        );

        vm.mockCall(
            oracleRegistry, abi.encodeWithSelector(OracleRegistry.isOracleActive.selector, sender), abi.encode(false)
        );

        vm.expectRevert("PriceRegistry: Price submitter is not an active oracle");
        vm.prank(sender);
        priceRegistry.setSettlementPrice(asset, expiryTime, settlementPriceDecimals, settlementPrice);
    }

    function testCannotSettlePriceWithUnregisteredOracle(
        address asset,
        uint88 expiryTime,
        uint128 _settlementPrice,
        uint8 settlementPriceDecimals
    ) public {
        settlementPriceDecimals = uint8(bound(settlementPriceDecimals, 0, 32));
        vm.assume(_settlementPrice > 0);
        vm.warp(expiryTime);

        uint256 settlementPrice = _settlementPrice * 10 ** settlementPriceDecimals;

        vm.mockCall(
            oracleRegistry,
            abi.encodeWithSelector(OracleRegistry.isOracleRegistered.selector, oracle),
            abi.encode(false)
        );

        vm.expectRevert("PriceRegistry: Price submitter is not an active oracle");
        priceRegistry.setSettlementPrice(asset, expiryTime, settlementPriceDecimals, settlementPrice);
    }

    function testCannotSettlePriceWithInactiveOracle(
        address asset,
        uint88 expiryTime,
        uint128 _settlementPrice,
        uint8 settlementPriceDecimals
    ) public {
        settlementPriceDecimals = uint8(bound(settlementPriceDecimals, 0, 32));
        vm.assume(_settlementPrice > 0);
        vm.warp(expiryTime);

        uint256 settlementPrice = _settlementPrice * 10 ** settlementPriceDecimals;

        vm.mockCall(
            oracleRegistry, abi.encodeWithSelector(OracleRegistry.isOracleRegistered.selector, oracle), abi.encode(true)
        );

        vm.mockCall(
            oracleRegistry, abi.encodeWithSelector(OracleRegistry.isOracleActive.selector, oracle), abi.encode(false)
        );

        vm.expectRevert("PriceRegistry: Price submitter is not an active oracle");
        priceRegistry.setSettlementPrice(asset, expiryTime, settlementPriceDecimals, settlementPrice);
    }

    function testCannotSettleFuturePrice(
        address asset,
        uint88 expiryTime,
        uint128 _settlementPrice,
        uint8 settlementPriceDecimals
    ) public {
        settlementPriceDecimals = uint8(bound(settlementPriceDecimals, 0, 32));
        expiryTime = uint88(bound(expiryTime, block.timestamp, type(uint88).max));
        vm.assume(_settlementPrice > 0);
        vm.warp(expiryTime - 1);

        uint256 settlementPrice = _settlementPrice * 10 ** settlementPriceDecimals;

        vm.expectRevert("PriceRegistry: Can't set a price for a time in the future");
        priceRegistry.setSettlementPrice(asset, expiryTime, settlementPriceDecimals, settlementPrice);
    }

    function testSetDisputePeriod(uint32 newDisputePeriod) public {
        uint32 initialDisputePeriod = uint32(uint256(vm.load(address(priceRegistry), disputePeriodSlot)));
        assertEq(initialDisputePeriod, disputePeriod);

        vm.expectEmit(false, false, false, true);
        emit DisputePeriodSet(newDisputePeriod);
        priceRegistry.setDisputePeriod(newDisputePeriod);
        uint32 currentDisputePeriod = uint32(uint256(vm.load(address(priceRegistry), disputePeriodSlot)));
        assertEq(currentDisputePeriod, newDisputePeriod);
    }

    function testCannotSetDisputePeriodWithUnauthorizedAccount(address sender) public {
        vm.assume(sender != priceRegistry.owner());
        vm.expectRevert(Unauthorized.selector);
        vm.prank(sender);
        priceRegistry.setDisputePeriod(disputePeriod);
    }

    function testCannotDisputePriceWithoutRole(
        address _oracle,
        address asset,
        uint88 expiryTime,
        uint8 settlementPriceDecimals,
        uint128 _settlementPrice
    ) public {
        settlementPriceDecimals = uint8(bound(settlementPriceDecimals, 0, 32));
        expiryTime = uint88(bound(expiryTime, block.timestamp + 1, type(uint88).max));
        vm.assume(_settlementPrice > 0);
        uint256 settlementPrice = _settlementPrice * 10 ** settlementPriceDecimals;

        vm.expectRevert("PriceRegistry: Caller is not a disputer");
        priceRegistry.disputeSettlementPrice(_oracle, asset, expiryTime, settlementPriceDecimals, settlementPrice);
    }

    function testCannotDisputePriceBeforeSettlement(
        address disputer,
        address _oracle,
        address asset,
        uint88 expiryTime,
        uint8 settlementPriceDecimals,
        uint128 _settlementPrice
    ) public {
        settlementPriceDecimals = uint8(bound(settlementPriceDecimals, 0, 32));
        expiryTime = uint88(bound(expiryTime, block.timestamp + 1, type(uint88).max));
        vm.assume(_settlementPrice > 0);
        uint256 settlementPrice = _settlementPrice * 10 ** settlementPriceDecimals;

        priceRegistry.grantRoles(disputer, disputerRole);

        vm.expectRevert("PriceRegistry: Settlement price has not been set");
        vm.prank(disputer);
        priceRegistry.disputeSettlementPrice(_oracle, asset, expiryTime, settlementPriceDecimals, settlementPrice);
    }

    function testCannotDisputePriceAfterDisputePeriod(
        address disputer,
        address _oracle,
        address asset,
        uint88 expiryTime,
        uint8 settlementPriceDecimals,
        uint128 _initialSettlementPrice,
        uint128 _correctSettlementPrice
    ) public {
        settlementPriceDecimals = uint8(bound(settlementPriceDecimals, 0, 32));
        expiryTime = uint88(bound(expiryTime, block.timestamp + 1, type(uint80).max));
        _initialSettlementPrice = uint128(bound(_initialSettlementPrice, 1, type(uint128).max));
        _correctSettlementPrice = uint128(bound(_correctSettlementPrice, 1, type(uint128).max));
        uint256 initialSettlementPrice = _initialSettlementPrice * 10 ** settlementPriceDecimals;
        uint256 correctSettlementPrice = _correctSettlementPrice * 10 ** settlementPriceDecimals;

        priceRegistry.grantRoles(disputer, disputerRole);

        vm.warp(expiryTime);
        vm.prank(_oracle);
        priceRegistry.setSettlementPrice(asset, expiryTime, settlementPriceDecimals, initialSettlementPrice);

        vm.warp(expiryTime + disputePeriod + 1);

        vm.expectRevert("PriceRegistry: Dispute period has ended");
        vm.prank(disputer);
        priceRegistry.disputeSettlementPrice(
            _oracle, asset, expiryTime, settlementPriceDecimals, correctSettlementPrice
        );
    }

    function testDisputeSettlementPrice(
        address disputer,
        address _oracle,
        address asset,
        uint32 newDisputePeriod,
        uint88 expiryTime,
        uint8 settlementPriceDecimals,
        uint128 _initialSettlementPrice,
        uint128 _correctSettlementPrice
    ) public {
        settlementPriceDecimals = uint8(bound(settlementPriceDecimals, 0, 32));
        expiryTime = uint88(bound(expiryTime, block.timestamp + 1, type(uint80).max));
        _initialSettlementPrice = uint128(bound(_initialSettlementPrice, 1, type(uint128).max));
        _correctSettlementPrice = uint128(bound(_correctSettlementPrice, 1, type(uint128).max));
        uint256 initialSettlementPrice = _initialSettlementPrice * 10 ** settlementPriceDecimals;
        uint256 correctSettlementPrice = _correctSettlementPrice * 10 ** settlementPriceDecimals;

        priceRegistry.setDisputePeriod(newDisputePeriod);

        priceRegistry.grantRoles(disputer, disputerRole);

        vm.warp(expiryTime);
        vm.prank(_oracle);
        priceRegistry.setSettlementPrice(asset, expiryTime, settlementPriceDecimals, initialSettlementPrice);

        vm.warp(expiryTime + newDisputePeriod);

        vm.expectEmit(true, true, true, true);
        emit PriceStored(_oracle, asset, expiryTime, settlementPriceDecimals, correctSettlementPrice);
        vm.prank(disputer);
        priceRegistry.disputeSettlementPrice(
            _oracle, asset, expiryTime, settlementPriceDecimals, correctSettlementPrice
        );
    }
}
