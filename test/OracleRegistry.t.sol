// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.16;

import {OracleRegistry} from "../src/pricing/OracleRegistry.sol";
import "forge-std/Test.sol";

contract OracleRegistryTest is Test {
    OracleRegistry oracleRegistry;

    event AddedOracle(address oracle, uint248 oracleId);

    event ActivatedOracle(address oracle);

    event DeactivatedOracle(address oracle);

    function setUp() public {
        oracleRegistry = new OracleRegistry();
    }

    function testAddOracle() public {
        address oracleOne = address(0x1);
        address oracleTwo = address(0x2);

        assertEq(oracleRegistry.getOraclesLength(), 0);

        vm.expectRevert("OracleRegistry: Oracle doesn't exist in registry");
        oracleRegistry.getOracleId(oracleOne);
        vm.expectRevert("OracleRegistry: Oracle doesn't exist in registry");
        oracleRegistry.getOracleId(oracleTwo);

        assertEq(oracleRegistry.isOracleRegistered(oracleOne), false);
        assertEq(oracleRegistry.isOracleRegistered(oracleTwo), false);

        vm.expectEmit(false, false, false, true);
        emit AddedOracle(oracleOne, 1);
        oracleRegistry.addOracle(oracleOne);
        assertEq(oracleRegistry.getOraclesLength(), 1);

        vm.expectEmit(false, false, false, true);
        emit AddedOracle(oracleTwo, 2);
        oracleRegistry.addOracle(oracleTwo);
        assertEq(oracleRegistry.getOraclesLength(), 2);

        assertEq(oracleRegistry.getOracleId(oracleOne), 1);
        assertEq(oracleRegistry.getOracleId(oracleTwo), 2);
        assertEq(oracleRegistry.isOracleRegistered(oracleOne), true);
        assertEq(oracleRegistry.isOracleRegistered(oracleTwo), true);
    }

    function testAddOracle(address oracleOne, address oracleTwo) public {
        vm.assume(oracleOne != oracleTwo);

        assertEq(oracleRegistry.getOraclesLength(), 0);

        vm.expectRevert("OracleRegistry: Oracle doesn't exist in registry");
        oracleRegistry.getOracleId(oracleOne);
        vm.expectRevert("OracleRegistry: Oracle doesn't exist in registry");
        oracleRegistry.getOracleId(oracleTwo);

        assertEq(oracleRegistry.isOracleRegistered(oracleOne), false);
        assertEq(oracleRegistry.isOracleRegistered(oracleTwo), false);

        vm.expectEmit(false, false, false, true);
        emit AddedOracle(oracleOne, 1);
        oracleRegistry.addOracle(oracleOne);
        assertEq(oracleRegistry.getOraclesLength(), 1);

        vm.expectEmit(false, false, false, true);
        emit AddedOracle(oracleTwo, 2);
        oracleRegistry.addOracle(oracleTwo);
        assertEq(oracleRegistry.getOraclesLength(), 2);

        assertEq(oracleRegistry.getOracleId(oracleOne), 1);
        assertEq(oracleRegistry.getOracleId(oracleTwo), 2);
        assertEq(oracleRegistry.isOracleRegistered(oracleOne), true);
        assertEq(oracleRegistry.isOracleRegistered(oracleTwo), true);
    }

    function testActivateOracle() public {
        address oracle = address(0x1);

        vm.expectRevert("OracleRegistry: Oracle doesn't exist in registry");
        oracleRegistry.getOracleId(oracle);

        assertEq(oracleRegistry.isOracleRegistered(oracle), false);

        oracleRegistry.addOracle(oracle);

        // oracle should be deactivated by default when added to the registry
        assertEq(oracleRegistry.isOracleActive(oracle), false);

        vm.expectEmit(false, false, false, true);
        emit ActivatedOracle(oracle);
        oracleRegistry.activateOracle(oracle);

        assertEq(oracleRegistry.isOracleActive(oracle), true);

        vm.expectEmit(false, false, false, true);
        emit DeactivatedOracle(oracle);
        oracleRegistry.deactivateOracle(oracle);

        assertEq(oracleRegistry.isOracleActive(oracle), false);
    }

    function testActivateOracle(address oracle) public {
        vm.expectRevert("OracleRegistry: Oracle doesn't exist in registry");
        oracleRegistry.getOracleId(oracle);

        assertEq(oracleRegistry.isOracleRegistered(oracle), false);

        oracleRegistry.addOracle(oracle);

        // oracle should be deactivated by default when added to the registry
        assertEq(oracleRegistry.isOracleActive(oracle), false);

        vm.expectEmit(false, false, false, true);
        emit ActivatedOracle(oracle);
        oracleRegistry.activateOracle(oracle);

        assertEq(oracleRegistry.isOracleActive(oracle), true);

        vm.expectEmit(false, false, false, true);
        emit DeactivatedOracle(oracle);
        oracleRegistry.deactivateOracle(oracle);

        assertEq(oracleRegistry.isOracleActive(oracle), false);
    }

    function testCannotAddSameOracleTwice() public {
        address oracle = address(0x1);

        oracleRegistry.addOracle(oracle);

        vm.expectRevert("OracleRegistry: Oracle already exists in registry");
        oracleRegistry.addOracle(oracle);
    }

    function testCannotAddSameOracleTwice(address oracle) public {
        oracleRegistry.addOracle(oracle);

        vm.expectRevert("OracleRegistry: Oracle already exists in registry");
        oracleRegistry.addOracle(oracle);
    }

    function testCannotActivateOracleTwice() public {
        address oracle = address(0x1);

        oracleRegistry.addOracle(oracle);

        vm.expectRevert("OracleRegistry: Oracle is already deactivated");
        oracleRegistry.deactivateOracle(oracle);

        oracleRegistry.activateOracle(oracle);

        vm.expectRevert("OracleRegistry: Oracle is already activated");
        oracleRegistry.activateOracle(oracle);
    }

    function testCannotActivateOracleTwice(address oracle) public {
        oracleRegistry.addOracle(oracle);

        vm.expectRevert("OracleRegistry: Oracle is already deactivated");
        oracleRegistry.deactivateOracle(oracle);

        oracleRegistry.activateOracle(oracle);

        vm.expectRevert("OracleRegistry: Oracle is already activated");
        oracleRegistry.activateOracle(oracle);
    }

    function testCannotOperateWithUnauthorizedAddress() public {
        address sender = address(1337);
        vm.startPrank(sender);

        vm.expectRevert("Ownable: caller is not the owner");
        oracleRegistry.addOracle(sender);

        vm.expectRevert("Ownable: caller is not the owner");
        oracleRegistry.activateOracle(sender);

        vm.expectRevert("Ownable: caller is not the owner");
        oracleRegistry.deactivateOracle(sender);

        vm.stopPrank();
    }

    function testCannotOperateWithUnauthorizedAddress(address sender) public {
        vm.assume(sender != address(this));
        vm.startPrank(sender);

        vm.expectRevert("Ownable: caller is not the owner");
        oracleRegistry.addOracle(sender);

        vm.expectRevert("Ownable: caller is not the owner");
        oracleRegistry.activateOracle(sender);

        vm.expectRevert("Ownable: caller is not the owner");
        oracleRegistry.deactivateOracle(sender);

        vm.stopPrank();
    }

    function testCannotHaveMoreOraclesThanMaxU248() public {
        address oracle = address(0x1);

        bytes32 oraclesSlot = bytes32(uint256(2));

        uint256 maxOraclesLength = type(uint248).max;

        uint256 oraclesLength = uint256(vm.load(address(oracleRegistry), oraclesSlot));

        assertEq(oraclesLength, 0);

        vm.store(address(oracleRegistry), oraclesSlot, bytes32(maxOraclesLength));

        assertEq(oracleRegistry.getOraclesLength(), maxOraclesLength);

        vm.expectRevert("OracleRegistry: oracles limit exceeded");
        oracleRegistry.addOracle(oracle);
    }

    function testCannotHaveMoreOraclesThanMaxU248(address oracle) public {
        bytes32 oraclesSlot = bytes32(uint256(2));

        uint256 maxOraclesLength = type(uint248).max;

        uint256 oraclesLength = uint256(vm.load(address(oracleRegistry), oraclesSlot));

        assertEq(oraclesLength, 0);

        vm.store(address(oracleRegistry), oraclesSlot, bytes32(maxOraclesLength));

        assertEq(oracleRegistry.getOraclesLength(), maxOraclesLength);

        vm.expectRevert("OracleRegistry: oracles limit exceeded");
        oracleRegistry.addOracle(oracle);
    }
}
