// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./ControllerTestBase.sol";

contract ClaimCollateralTest is ControllerTestBase {
    function testCannotClaimCollateralFromInvalidOption() public {
        vm.startPrank(user);

        uint256 invalidCTokenId = 123;
        vm.expectRevert();
        controller.claimCollateral(invalidCTokenId, 1 ether);

        vm.stopPrank();
    }

    function testCannotClaimCollateralBeforeExpiry() public {
        vm.startPrank(user);

        vm.expectRevert(bytes("Can not claim collateral from options before their expiry"));
        controller.claimCollateral(cTokenIdPut400, 1 ether);

        vm.stopPrank();
    }

    function testCannotClaimCollateralBeforeSettlement() public {
        vm.startPrank(user);

        uint256 initialBlockTimestamp = block.timestamp;
        vm.warp(expiryTimestamp + 3600);

        vm.mockCall(priceRegistry, abi.encodeWithSelector(IPriceRegistry.hasSettlementPrice.selector), abi.encode(true));
        vm.mockCall(
            priceRegistry,
            abi.encodeWithSelector(IPriceRegistry.getOptionPriceStatus.selector, oracle, expiryTimestamp, address(WETH)),
            abi.encode(PriceStatus.AWAITING_SETTLEMENT_PRICE)
        );

        vm.expectRevert(bytes("Can not claim collateral before option is settled"));
        controller.claimCollateral(cTokenIdPut400, 1 ether);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testCannotClaimCollateralDuringDisputePeriod() public {
        vm.startPrank(user);

        uint256 initialBlockTimestamp = block.timestamp;
        vm.warp(expiryTimestamp + 3600);

        vm.mockCall(priceRegistry, abi.encodeWithSelector(IPriceRegistry.hasSettlementPrice.selector), abi.encode(true));
        vm.mockCall(
            priceRegistry,
            abi.encodeWithSelector(IPriceRegistry.getOptionPriceStatus.selector, oracle, expiryTimestamp, address(WETH)),
            abi.encode(PriceStatus.DISPUTABLE)
        );

        vm.expectRevert(bytes("Can not claim collateral before option is settled"));
        controller.claimCollateral(cTokenIdPut400, 1 ether);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimFullCollateralITMPut() public {
        vm.startPrank(user);

        uint256 expiryPrice = 300 ether;
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 1 ether;
        uint256 amountToClaim = optionsAmount;
        uint256 collateralAmount = qTokenPut400.strikePrice();
        uint256 claimableCollateral = expiryPrice;

        // mint the option to the user
        deal(address(BUSD), user, collateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut400), optionsAmount);

        // advance time and mock the option being expired In The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim all of the collateral from the expired option
        controller.claimCollateral(cTokenIdPut400, amountToClaim);

        // check balances
        assertEq(BUSD.balanceOf(user), claimableCollateral);
        assertEq(BUSD.balanceOf(address(controller)), collateralAmount - claimableCollateral);

        assertEq(qTokenPut400.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut400), 0);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimPartialCollateralITMPut() public {
        vm.startPrank(user);

        uint256 expiryPrice = 220 ether;
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 3 ether;
        uint256 amountToClaim = 2 ether;
        uint256 collateralAmount = qTokenPut400.strikePrice() * 3;
        uint256 claimableCollateral = expiryPrice * 2;

        // mint the option to the user
        deal(address(BUSD), user, collateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut400), optionsAmount);

        // advance time and mock the option being expired In The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim some of the collateral from the expired option
        controller.claimCollateral(cTokenIdPut400, amountToClaim);

        // check balances
        assertEq(BUSD.balanceOf(user), claimableCollateral);
        assertEq(BUSD.balanceOf(address(controller)), collateralAmount - claimableCollateral);

        assertEq(qTokenPut400.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut400), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimFullCollateralOTMPut() public {
        vm.startPrank(user);

        uint256 expiryPrice = 500 ether;
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 4 ether;
        uint256 amountToClaim = optionsAmount;
        uint256 collateralAmount = qTokenPut400.strikePrice() * 4;
        uint256 claimableCollateral = collateralAmount;

        // mint the option to the user
        deal(address(BUSD), user, collateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut400), optionsAmount);

        // advance time and mock the option being expired Out of The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim all of the collateral from the expired option
        controller.claimCollateral(cTokenIdPut400, amountToClaim);

        // check balances
        assertEq(BUSD.balanceOf(user), claimableCollateral);
        assertEq(BUSD.balanceOf(address(controller)), collateralAmount - claimableCollateral);

        assertEq(qTokenPut400.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut400), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimPartialCollateralOTMPut() public {
        vm.startPrank(user);

        uint256 expiryPrice = 500 ether;
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 6 ether;
        uint256 amountToClaim = 3 ether;
        uint256 collateralAmount = qTokenPut400.strikePrice() * 6;
        uint256 claimableCollateral = qTokenPut400.strikePrice() * 3;

        // mint the option to the user
        deal(address(BUSD), user, collateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut400), optionsAmount);

        // advance time and mock the option being expired Out of The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim some of the collateral from the expired option
        controller.claimCollateral(cTokenIdPut400, amountToClaim);

        // check balances
        assertEq(BUSD.balanceOf(user), claimableCollateral);
        assertEq(BUSD.balanceOf(address(controller)), collateralAmount - claimableCollateral);

        assertEq(qTokenPut400.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut400), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);
        vm.stopPrank();
    }

    function testClaimFullCollateralATMPut() public {
        vm.startPrank(user);

        uint256 expiryPrice = qTokenPut400.strikePrice();
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 2 ether;
        uint256 amountToClaim = optionsAmount;
        uint256 collateralAmount = qTokenPut400.strikePrice() * 2;
        uint256 claimableCollateral = collateralAmount;

        // mint the option to the user
        deal(address(BUSD), user, collateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut400), optionsAmount);

        // advance time and mock the option being expired At The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim all of the collateral from the expired option
        controller.claimCollateral(cTokenIdPut400, amountToClaim);

        // check balances
        assertEq(BUSD.balanceOf(user), claimableCollateral);
        assertEq(BUSD.balanceOf(address(controller)), collateralAmount - claimableCollateral);

        assertEq(qTokenPut400.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut400), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimPartialCollateralATMPut() public {
        vm.startPrank(user);

        uint256 expiryPrice = qTokenPut400.strikePrice();
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 5 ether;
        uint256 amountToClaim = 3 ether;
        uint256 collateralAmount = qTokenPut400.strikePrice() * 5;
        uint256 claimableCollateral = qTokenPut400.strikePrice() * 3;

        // mint the option to the user
        deal(address(BUSD), user, collateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut400), optionsAmount);

        // advance time and mock the option being expired At The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim some of the collateral from the expired option
        controller.claimCollateral(cTokenIdPut400, amountToClaim);

        // check balances
        assertEq(BUSD.balanceOf(user), claimableCollateral);
        assertEq(BUSD.balanceOf(address(controller)), collateralAmount - claimableCollateral);

        assertEq(qTokenPut400.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut400), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimFullCollateralITMCall() public {
        vm.startPrank(user);

        uint256 expiryPrice = 2500 ether;
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 7 ether;
        uint256 amountToClaim = optionsAmount;
        uint256 collateralAmount = optionsAmount;
        uint256 claimableCollateral =
            amountToClaim - (expiryPrice - qTokenCall2000.strikePrice()) * amountToClaim / expiryPrice;

        // mint the option to the user
        deal(address(WETH), user, collateralAmount, true);
        WETH.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenCall2000), optionsAmount);

        // advance time and mock the option being expired In The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim all of the collateral from the expired option
        controller.claimCollateral(cTokenIdCall2000, amountToClaim);

        // check balances
        assertEq(WETH.balanceOf(user), claimableCollateral);
        assertEq(WETH.balanceOf(address(controller)), collateralAmount - claimableCollateral);

        assertEq(qTokenCall2000.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall2000), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimPartialCollateralITMCall() public {
        vm.startPrank(user);

        uint256 expiryPrice = 2500 ether;
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 3 ether;
        uint256 amountToClaim = 1 ether;
        uint256 collateralAmount = optionsAmount;
        uint256 claimableCollateral =
            amountToClaim - (expiryPrice - qTokenCall2000.strikePrice()) * amountToClaim / expiryPrice;

        // mint the option to the user
        deal(address(WETH), user, collateralAmount, true);
        WETH.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenCall2000), optionsAmount);

        // advance time and mock the option being expired In The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim some of the collateral from the expired option
        controller.claimCollateral(cTokenIdCall2000, amountToClaim);

        // check balances
        assertEq(WETH.balanceOf(user), claimableCollateral);
        assertEq(WETH.balanceOf(address(controller)), collateralAmount - claimableCollateral);

        assertEq(qTokenCall2000.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall2000), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimFullCollateralOTMCall() public {
        vm.startPrank(user);

        uint256 expiryPrice = 1800 ether;
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 14 ether;
        uint256 amountToClaim = optionsAmount;
        uint256 collateralAmount = optionsAmount;
        uint256 claimableCollateral = amountToClaim;

        // mint the option to the user
        deal(address(WETH), user, collateralAmount, true);
        WETH.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenCall2000), optionsAmount);

        // advance time and mock the option being expired Out of The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim all of the collateral from the expired option
        controller.claimCollateral(cTokenIdCall2000, amountToClaim);

        // check balances
        assertEq(WETH.balanceOf(user), claimableCollateral);
        assertEq(WETH.balanceOf(address(controller)), collateralAmount - claimableCollateral);

        assertEq(qTokenCall2000.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall2000), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimPartialCollateralOTMCall() public {
        vm.startPrank(user);

        uint256 expiryPrice = 1800 ether;
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 5 ether;
        uint256 amountToClaim = 3 ether;
        uint256 collateralAmount = optionsAmount;
        uint256 claimableCollateral = amountToClaim;

        // mint the option to the user
        deal(address(WETH), user, collateralAmount, true);
        WETH.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenCall2000), optionsAmount);

        // advance time and mock the option being expired Out of The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim some of the collateral from the expired option
        controller.claimCollateral(cTokenIdCall2000, amountToClaim);

        // check balances
        assertEq(WETH.balanceOf(user), claimableCollateral);
        assertEq(WETH.balanceOf(address(controller)), collateralAmount - claimableCollateral);

        assertEq(qTokenCall2000.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall2000), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimFullCollateralATMCall() public {
        vm.startPrank(user);

        uint256 expiryPrice = qTokenCall2000.strikePrice();
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 2 ether;
        uint256 amountToClaim = optionsAmount;
        uint256 collateralAmount = optionsAmount;
        uint256 claimableCollateral = amountToClaim;

        // mint the option to the user
        deal(address(WETH), user, collateralAmount, true);
        WETH.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenCall2000), optionsAmount);

        // advance time and mock the option being expired At The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim all of the collateral from the expired option
        controller.claimCollateral(cTokenIdCall2000, amountToClaim);

        // check balances
        assertEq(WETH.balanceOf(user), claimableCollateral);
        assertEq(WETH.balanceOf(address(controller)), collateralAmount - claimableCollateral);

        assertEq(qTokenCall2000.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall2000), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimPartialCollateralATMCall() public {
        vm.startPrank(user);

        uint256 expiryPrice = qTokenCall2000.strikePrice();
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 9 ether;
        uint256 amountToClaim = 5 ether;
        uint256 collateralAmount = optionsAmount;
        uint256 claimableCollateral = amountToClaim;

        // mint the option to the user
        deal(address(WETH), user, collateralAmount, true);
        WETH.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenCall2000), optionsAmount);

        // advance time and mock the option being expired At The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim some of the collateral from the expired option
        controller.claimCollateral(cTokenIdCall2000, amountToClaim);

        // check balances
        assertEq(WETH.balanceOf(user), claimableCollateral);
        assertEq(WETH.balanceOf(address(controller)), collateralAmount - claimableCollateral);

        assertEq(qTokenCall2000.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall2000), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimCollateralITMPutCreditSpread() public {
        vm.startPrank(user);

        uint256 expiryPrice = 1100 ether;
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 3 ether;
        uint256 amountToClaim = optionsAmount;
        uint256 put400CollateralAmount = qTokenPut400.strikePrice() * 3;
        uint256 put1400CollateralAmount = qTokenPut1400.strikePrice() * 3;
        uint256 spreadCollateralAmount = put1400CollateralAmount - put400CollateralAmount;
        uint256 totalRequiredCollateral = put1400CollateralAmount;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenPut1400), address(qTokenPut400));

        uint256 put400Payout = 0;
        uint256 put1400Payout = (qTokenPut1400.strikePrice() - expiryPrice) * 3;

        uint256 claimableCollateral = put400Payout + spreadCollateralAmount - put1400Payout;

        // mint the option to be used as collateral for the spread
        deal(address(BUSD), user, put400CollateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut400), optionsAmount);

        // mint the spread using the previously minted option as collateral
        deal(address(BUSD), user, spreadCollateralAmount, true);
        controller.mintSpread(address(qTokenPut1400), address(qTokenPut400), optionsAmount);

        // advance time and mock the option being expired In The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim the collateral from the expired spread
        controller.claimCollateral(spreadCTokenId, amountToClaim);

        // check balances
        assertEq(BUSD.balanceOf(user), claimableCollateral);
        assertEq(BUSD.balanceOf(address(controller)), totalRequiredCollateral - claimableCollateral);

        assertEq(qTokenPut400.balanceOf(user), 0);
        assertEq(qTokenPut1400.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut400), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut1400), 0);
        assertEq(collateralToken.balanceOf(user, spreadCTokenId), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimCollateralUncoveredITMPutCreditSpread() public {
        vm.startPrank(user);

        uint256 expiryPrice = 300 ether;
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 5 ether;
        uint256 amountToClaim = optionsAmount;
        uint256 put400CollateralAmount = qTokenPut400.strikePrice() * 5;
        uint256 put1400CollateralAmount = qTokenPut1400.strikePrice() * 5;
        uint256 spreadCollateralAmount = put1400CollateralAmount - put400CollateralAmount;
        uint256 totalRequiredCollateral = put1400CollateralAmount;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenPut1400), address(qTokenPut400));

        uint256 put400Payout = (qTokenPut400.strikePrice() - expiryPrice) * 5;
        uint256 put1400Payout = (qTokenPut1400.strikePrice() - expiryPrice) * 5;

        uint256 claimableCollateral =
            spreadCollateralAmount > put1400Payout ? put400Payout + spreadCollateralAmount - put1400Payout : 0;

        // mint the option to be used as collateral for the spread
        deal(address(BUSD), user, put400CollateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut400), optionsAmount);

        // mint the spread using the previously minted option as collateral
        deal(address(BUSD), user, spreadCollateralAmount, true);
        controller.mintSpread(address(qTokenPut1400), address(qTokenPut400), optionsAmount);

        // advance time and mock the option being expired In The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim the collateral from the expired spread
        controller.claimCollateral(spreadCTokenId, amountToClaim);

        // check balances
        assertEq(BUSD.balanceOf(user), claimableCollateral);
        assertEq(BUSD.balanceOf(address(controller)), totalRequiredCollateral - claimableCollateral);

        assertEq(qTokenPut400.balanceOf(user), 0);
        assertEq(qTokenPut1400.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut400), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut1400), 0);
        assertEq(collateralToken.balanceOf(user, spreadCTokenId), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimCollateralOTMPutCreditSpread() public {
        vm.startPrank(user);

        uint256 expiryPrice = 1800 ether;
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 7 ether;
        uint256 amountToClaim = optionsAmount;
        uint256 put400CollateralAmount = qTokenPut400.strikePrice() * 7;
        uint256 put1400CollateralAmount = qTokenPut1400.strikePrice() * 7;
        uint256 spreadCollateralAmount = put1400CollateralAmount - put400CollateralAmount;
        uint256 totalRequiredCollateral = put1400CollateralAmount;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenPut1400), address(qTokenPut400));

        uint256 put400Payout = 0;
        uint256 put1400Payout = 0;

        uint256 claimableCollateral = put400Payout + spreadCollateralAmount - put1400Payout;

        // mint the option to be used as collateral for the spread
        deal(address(BUSD), user, put400CollateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut400), optionsAmount);

        // mint the spread using the previously minted option as collateral
        deal(address(BUSD), user, spreadCollateralAmount, true);
        controller.mintSpread(address(qTokenPut1400), address(qTokenPut400), optionsAmount);

        // advance time and mock the option being expired Out of The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim the collateral from the expired spread
        controller.claimCollateral(spreadCTokenId, amountToClaim);

        // check balances
        assertEq(BUSD.balanceOf(user), claimableCollateral);
        assertEq(BUSD.balanceOf(address(controller)), totalRequiredCollateral - claimableCollateral);

        assertEq(qTokenPut400.balanceOf(user), 0);
        assertEq(qTokenPut1400.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut400), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut1400), 0);
        assertEq(collateralToken.balanceOf(user, spreadCTokenId), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimCollateralATMPutCreditSpread() public {
        vm.startPrank(user);

        uint256 expiryPrice = qTokenPut1400.strikePrice();
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 1 ether;
        uint256 amountToClaim = optionsAmount;
        uint256 put400CollateralAmount = qTokenPut400.strikePrice();
        uint256 put1400CollateralAmount = qTokenPut1400.strikePrice();
        uint256 spreadCollateralAmount = put1400CollateralAmount - put400CollateralAmount;
        uint256 totalRequiredCollateral = put1400CollateralAmount;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenPut1400), address(qTokenPut400));

        uint256 put400Payout = 0;
        uint256 put1400Payout = (qTokenPut1400.strikePrice() - expiryPrice);

        uint256 claimableCollateral =
            spreadCollateralAmount > put1400Payout ? put400Payout + spreadCollateralAmount - put1400Payout : 0;

        // mint the option to be used as collateral for the spread
        deal(address(BUSD), user, put400CollateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut400), optionsAmount);

        // mint the spread using the previously minted option as collateral
        deal(address(BUSD), user, spreadCollateralAmount, true);
        controller.mintSpread(address(qTokenPut1400), address(qTokenPut400), optionsAmount);

        // advance time and mock the option being expired At The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim the collateral from the expired spread
        controller.claimCollateral(spreadCTokenId, amountToClaim);

        // check balances
        assertEq(BUSD.balanceOf(user), claimableCollateral);
        assertEq(BUSD.balanceOf(address(controller)), totalRequiredCollateral - claimableCollateral);

        assertEq(qTokenPut400.balanceOf(user), 0);
        assertEq(qTokenPut1400.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut400), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut1400), 0);
        assertEq(collateralToken.balanceOf(user, spreadCTokenId), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimCollateralITMPutDebitSpread() public {
        vm.startPrank(user);

        uint256 expiryPrice = 200 ether;
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 8 ether;
        uint256 amountToClaim = optionsAmount;
        uint256 put1400CollateralAmount = qTokenPut1400.strikePrice() * 8;
        uint256 spreadCollateralAmount = 0;
        uint256 totalRequiredCollateral = put1400CollateralAmount;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenPut400), address(qTokenPut1400));

        uint256 put1400Payout =
            qTokenPut1400.strikePrice() > expiryPrice ? (qTokenPut1400.strikePrice() - expiryPrice) * 8 : 0;
        uint256 put400Payout =
            qTokenPut400.strikePrice() > expiryPrice ? (qTokenPut400.strikePrice() - expiryPrice) * 8 : 0;

        uint256 claimableCollateral = put1400Payout + spreadCollateralAmount - put400Payout;

        // mint the option to be used as collateral for the spread
        deal(address(BUSD), user, put1400CollateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut1400), optionsAmount);

        // mint the spread using the previously minted option as collateral
        controller.mintSpread(address(qTokenPut400), address(qTokenPut1400), optionsAmount);

        // advance time and mock the option being expired In The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim the collateral from the expired spread
        controller.claimCollateral(spreadCTokenId, amountToClaim);

        // check balances
        assertEq(BUSD.balanceOf(user), claimableCollateral);
        assertEq(BUSD.balanceOf(address(controller)), totalRequiredCollateral - claimableCollateral);

        assertEq(qTokenPut1400.balanceOf(user), 0);
        assertEq(qTokenPut400.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut400), 0);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut1400), optionsAmount);
        assertEq(collateralToken.balanceOf(user, spreadCTokenId), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimCollateralOTMPutDebitSpread() public {
        vm.startPrank(user);

        uint256 expiryPrice = 600 ether;
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 8 ether;
        uint256 amountToClaim = optionsAmount;
        uint256 put1400CollateralAmount = qTokenPut1400.strikePrice() * 8;
        uint256 spreadCollateralAmount = 0;
        uint256 totalRequiredCollateral = put1400CollateralAmount;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenPut400), address(qTokenPut1400));

        uint256 put1400Payout =
            qTokenPut1400.strikePrice() > expiryPrice ? (qTokenPut1400.strikePrice() - expiryPrice) * 8 : 0;
        uint256 put400Payout =
            qTokenPut400.strikePrice() > expiryPrice ? (qTokenPut400.strikePrice() - expiryPrice) * 8 : 0;

        uint256 claimableCollateral = put1400Payout + spreadCollateralAmount - put400Payout;

        // mint the option to be used as collateral for the spread
        deal(address(BUSD), user, put1400CollateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut1400), optionsAmount);

        // mint the spread using the previously minted option as collateral
        controller.mintSpread(address(qTokenPut400), address(qTokenPut1400), optionsAmount);

        // advance time and mock the option being expired Out of The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim the collateral from the expired spread
        controller.claimCollateral(spreadCTokenId, amountToClaim);

        // check balances
        assertEq(BUSD.balanceOf(user), claimableCollateral);
        assertEq(BUSD.balanceOf(address(controller)), totalRequiredCollateral - claimableCollateral);

        assertEq(qTokenPut1400.balanceOf(user), 0);
        assertEq(qTokenPut400.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut400), 0);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut1400), optionsAmount);
        assertEq(collateralToken.balanceOf(user, spreadCTokenId), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimCollateralATMPutDebitSpread() public {
        vm.startPrank(user);

        uint256 expiryPrice = qTokenPut400.strikePrice();
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 8 ether;
        uint256 amountToClaim = optionsAmount;
        uint256 put1400CollateralAmount = qTokenPut1400.strikePrice() * 8;
        uint256 spreadCollateralAmount = 0;
        uint256 totalRequiredCollateral = put1400CollateralAmount;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenPut400), address(qTokenPut1400));

        uint256 put1400Payout =
            qTokenPut1400.strikePrice() > expiryPrice ? (qTokenPut1400.strikePrice() - expiryPrice) * 8 : 0;
        uint256 put400Payout =
            qTokenPut400.strikePrice() > expiryPrice ? (qTokenPut400.strikePrice() - expiryPrice) * 8 : 0;

        uint256 claimableCollateral = put1400Payout + spreadCollateralAmount - put400Payout;

        // mint the option to be used as collateral for the spread
        deal(address(BUSD), user, put1400CollateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut1400), optionsAmount);

        // mint the spread using the previously minted option as collateral
        controller.mintSpread(address(qTokenPut400), address(qTokenPut1400), optionsAmount);

        // advance time and mock the option being expired At The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim the collateral from the expired spread
        controller.claimCollateral(spreadCTokenId, amountToClaim);

        // check balances
        assertEq(BUSD.balanceOf(user), claimableCollateral);
        assertEq(BUSD.balanceOf(address(controller)), totalRequiredCollateral - claimableCollateral);

        assertEq(qTokenPut1400.balanceOf(user), 0);
        assertEq(qTokenPut400.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut400), 0);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut1400), optionsAmount);
        assertEq(collateralToken.balanceOf(user, spreadCTokenId), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimCollateralITMCallCreditSpread() public {
        vm.startPrank(user);

        uint256 expiryPrice = 3200 ether;
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 2 ether;
        uint256 amountToClaim = optionsAmount;
        uint256 call3520CollateralAmount = optionsAmount;
        uint256 spreadCollateralAmount = 363636363636363637;
        uint256 totalRequiredCollateral = call3520CollateralAmount + spreadCollateralAmount;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenCall2880), address(qTokenCall3520));
        uint256 call3520Payout = expiryPrice > qTokenCall3520.strikePrice()
            ? ((expiryPrice - qTokenCall3520.strikePrice()) * 2 ether) / expiryPrice
            : 0;

        uint256 call2880Payout = expiryPrice > qTokenCall2880.strikePrice()
            ? ((expiryPrice - qTokenCall2880.strikePrice()) * 2 ether) / expiryPrice
            : 0;

        uint256 claimableCollateral = call3520Payout + spreadCollateralAmount - call2880Payout;

        // mint the option to be used as collateral for the spread
        deal(address(WETH), user, call3520CollateralAmount, true);
        WETH.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenCall3520), optionsAmount);

        // mint the spread using the previously minted option as collateral
        deal(address(WETH), user, spreadCollateralAmount, true);
        controller.mintSpread(address(qTokenCall2880), address(qTokenCall3520), optionsAmount);

        // advance time and mock the option being expired In The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim the collateral from the expired spread
        controller.claimCollateral(spreadCTokenId, amountToClaim);

        // check balances
        assertEq(WETH.balanceOf(user), claimableCollateral - 1); // round down
        assertEq(WETH.balanceOf(address(controller)), totalRequiredCollateral - claimableCollateral + 1); // round up
        assertEq(qTokenCall3520.balanceOf(user), 0);
        assertEq(qTokenCall2880.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall2880), 0);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall3520), optionsAmount);
        assertEq(collateralToken.balanceOf(user, spreadCTokenId), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimCollateralOTMCallCreditSpread() public {
        vm.startPrank(user);

        uint256 expiryPrice = 2600 ether;
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 9 ether;
        uint256 amountToClaim = optionsAmount;
        uint256 call3520CollateralAmount = optionsAmount;
        uint256 spreadCollateralAmount = 1636363636363636364;
        uint256 totalRequiredCollateral = call3520CollateralAmount + spreadCollateralAmount;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenCall2880), address(qTokenCall3520));
        uint256 call3520Payout = expiryPrice > qTokenCall3520.strikePrice()
            ? ((expiryPrice - qTokenCall3520.strikePrice()) * 9 ether) / expiryPrice
            : 0;

        uint256 call2880Payout = expiryPrice > qTokenCall2880.strikePrice()
            ? ((expiryPrice - qTokenCall2880.strikePrice()) * 9 ether) / expiryPrice
            : 0;

        uint256 claimableCollateral = call3520Payout + spreadCollateralAmount - call2880Payout;

        // mint the option to be used as collateral for the spread
        deal(address(WETH), user, call3520CollateralAmount, true);
        WETH.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenCall3520), optionsAmount);

        // mint the spread using the previously minted option as collateral
        deal(address(WETH), user, spreadCollateralAmount, true);
        controller.mintSpread(address(qTokenCall2880), address(qTokenCall3520), optionsAmount);

        // advance time and mock the option being expired Out of The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim the collateral from the expired spread
        controller.claimCollateral(spreadCTokenId, amountToClaim);

        // check balances
        assertEq(WETH.balanceOf(user), claimableCollateral - 1); // round down
        assertEq(WETH.balanceOf(address(controller)), totalRequiredCollateral - claimableCollateral + 1); // round up
        assertEq(qTokenCall3520.balanceOf(user), 0);
        assertEq(qTokenCall2880.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall2880), 0);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall3520), optionsAmount);
        assertEq(collateralToken.balanceOf(user, spreadCTokenId), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimCollateralATMCallCreditSpread() public {
        vm.startPrank(user);

        uint256 expiryPrice = 2880 ether;
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 7 ether;
        uint256 amountToClaim = optionsAmount;
        uint256 call3520CollateralAmount = optionsAmount;
        uint256 spreadCollateralAmount = 1272727272727272728;
        uint256 totalRequiredCollateral = call3520CollateralAmount + spreadCollateralAmount;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenCall2880), address(qTokenCall3520));
        uint256 call3520Payout = expiryPrice > qTokenCall3520.strikePrice()
            ? ((expiryPrice - qTokenCall3520.strikePrice()) * 7 ether) / expiryPrice
            : 0;

        uint256 call2880Payout = expiryPrice > qTokenCall2880.strikePrice()
            ? ((expiryPrice - qTokenCall2880.strikePrice()) * 7 ether) / expiryPrice
            : 0;

        uint256 claimableCollateral = call3520Payout + spreadCollateralAmount - call2880Payout;

        // mint the option to be used as collateral for the spread
        deal(address(WETH), user, call3520CollateralAmount, true);
        WETH.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenCall3520), optionsAmount);

        // mint the spread using the previously minted option as collateral
        deal(address(WETH), user, spreadCollateralAmount, true);
        controller.mintSpread(address(qTokenCall2880), address(qTokenCall3520), optionsAmount);

        // advance time and mock the option being expired At The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim the collateral from the expired spread
        controller.claimCollateral(spreadCTokenId, amountToClaim);

        // check balances
        assertEq(WETH.balanceOf(user), claimableCollateral - 1); // round down
        assertEq(WETH.balanceOf(address(controller)), totalRequiredCollateral - claimableCollateral + 1); // round up
        assertEq(qTokenCall3520.balanceOf(user), 0);
        assertEq(qTokenCall2880.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall2880), 0);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall3520), optionsAmount);
        assertEq(collateralToken.balanceOf(user, spreadCTokenId), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimCollateralITMCallCreditSpreadAtLongOptionStrike() public {
        vm.startPrank(user);

        uint256 expiryPrice = 3520 ether;
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 4 ether;
        uint256 amountToClaim = optionsAmount;
        uint256 call3520CollateralAmount = optionsAmount;
        uint256 spreadCollateralAmount = 727272727272727273;
        uint256 totalRequiredCollateral = call3520CollateralAmount + spreadCollateralAmount;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenCall2880), address(qTokenCall3520));
        uint256 call3520Payout = expiryPrice > qTokenCall3520.strikePrice()
            ? ((expiryPrice - qTokenCall3520.strikePrice()) * 4 ether) / expiryPrice
            : 0;

        uint256 call2880Payout = expiryPrice > qTokenCall2880.strikePrice()
            ? ((expiryPrice - qTokenCall2880.strikePrice()) * 4 ether) / expiryPrice
            : 0;

        uint256 claimableCollateral =
            call3520Payout > call2880Payout ? call3520Payout + spreadCollateralAmount - call2880Payout : 0;

        // mint the option to be used as collateral for the spread
        deal(address(WETH), user, call3520CollateralAmount, true);
        WETH.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenCall3520), optionsAmount);

        // mint the spread using the previously minted option as collateral
        deal(address(WETH), user, spreadCollateralAmount, true);
        controller.mintSpread(address(qTokenCall2880), address(qTokenCall3520), optionsAmount);

        // advance time and mock the option being expired In The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim the collateral from the expired spread
        controller.claimCollateral(spreadCTokenId, amountToClaim);

        // check balances
        assertEq(WETH.balanceOf(user), claimableCollateral);
        assertEq(WETH.balanceOf(address(controller)), totalRequiredCollateral - claimableCollateral);
        assertEq(qTokenCall3520.balanceOf(user), 0);
        assertEq(qTokenCall2880.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall2880), 0);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall3520), optionsAmount);
        assertEq(collateralToken.balanceOf(user, spreadCTokenId), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimCollateralITMCallDebitSpread() public {
        vm.startPrank(user);

        uint256 expiryPrice = 4000 ether;
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 6 ether;
        uint256 amountToClaim = optionsAmount;
        uint256 call2880CollateralAmount = optionsAmount;
        uint256 spreadCollateralAmount = 0;
        uint256 totalRequiredCollateral = call2880CollateralAmount + spreadCollateralAmount;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenCall3520), address(qTokenCall2880));
        uint256 call3520Payout = expiryPrice > qTokenCall3520.strikePrice()
            ? ((expiryPrice - qTokenCall3520.strikePrice()) * 6 ether) / expiryPrice
            : 0;

        uint256 call2880Payout = expiryPrice > qTokenCall2880.strikePrice()
            ? ((expiryPrice - qTokenCall2880.strikePrice()) * 6 ether) / expiryPrice
            : 0;

        uint256 claimableCollateral = call2880Payout + spreadCollateralAmount - call3520Payout;

        // mint the option to be used as collateral for the spread
        deal(address(WETH), user, call2880CollateralAmount, true);
        WETH.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenCall2880), optionsAmount);

        // mint the spread using the previously minted option as collateral
        controller.mintSpread(address(qTokenCall3520), address(qTokenCall2880), optionsAmount);

        // advance time and mock the option being expired In The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim the collateral from the expired spread
        controller.claimCollateral(spreadCTokenId, amountToClaim);

        // check balances
        assertEq(WETH.balanceOf(user), claimableCollateral);
        assertEq(WETH.balanceOf(address(controller)), totalRequiredCollateral - claimableCollateral);
        assertEq(qTokenCall3520.balanceOf(user), optionsAmount);
        assertEq(qTokenCall2880.balanceOf(user), 0);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall2880), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall3520), 0);
        assertEq(collateralToken.balanceOf(user, spreadCTokenId), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimCollateralOTMCallDebitSpread() public {
        vm.startPrank(user);

        uint256 expiryPrice = 3000 ether;
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 8 ether;
        uint256 amountToClaim = optionsAmount;
        uint256 call2880CollateralAmount = optionsAmount;
        uint256 spreadCollateralAmount = 0;
        uint256 totalRequiredCollateral = call2880CollateralAmount + spreadCollateralAmount;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenCall3520), address(qTokenCall2880));
        uint256 call3520Payout = expiryPrice > qTokenCall3520.strikePrice()
            ? ((expiryPrice - qTokenCall3520.strikePrice()) * 8 ether) / expiryPrice
            : 0;

        uint256 call2880Payout = expiryPrice > qTokenCall2880.strikePrice()
            ? ((expiryPrice - qTokenCall2880.strikePrice()) * 8 ether) / expiryPrice
            : 0;

        uint256 claimableCollateral = call2880Payout + spreadCollateralAmount - call3520Payout;

        // mint the option to be used as collateral for the spread
        deal(address(WETH), user, call2880CollateralAmount, true);
        WETH.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenCall2880), optionsAmount);

        // mint the spread using the previously minted option as collateral
        controller.mintSpread(address(qTokenCall3520), address(qTokenCall2880), optionsAmount);

        // advance time and mock the option being expired Out of The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim the collateral from the expired spread
        controller.claimCollateral(spreadCTokenId, amountToClaim);

        // check balances
        assertEq(WETH.balanceOf(user), claimableCollateral);
        assertEq(WETH.balanceOf(address(controller)), totalRequiredCollateral - claimableCollateral);
        assertEq(qTokenCall3520.balanceOf(user), optionsAmount);
        assertEq(qTokenCall2880.balanceOf(user), 0);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall2880), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall3520), 0);
        assertEq(collateralToken.balanceOf(user, spreadCTokenId), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }

    function testClaimCollateralATMCallDebitSpread() public {
        vm.startPrank(user);

        uint256 expiryPrice = 3520 ether;
        uint256 initialBlockTimestamp = block.timestamp;
        uint256 optionsAmount = 3.15 ether;
        uint256 amountToClaim = optionsAmount;
        uint256 call2880CollateralAmount = optionsAmount;
        uint256 spreadCollateralAmount = 0;
        uint256 totalRequiredCollateral = call2880CollateralAmount + spreadCollateralAmount;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenCall3520), address(qTokenCall2880));
        uint256 call3520Payout = expiryPrice > qTokenCall3520.strikePrice()
            ? ((expiryPrice - qTokenCall3520.strikePrice()) * 3.15 ether) / expiryPrice
            : 0;

        uint256 call2880Payout = expiryPrice > qTokenCall2880.strikePrice()
            ? ((expiryPrice - qTokenCall2880.strikePrice()) * 3.15 ether) / expiryPrice
            : 0;

        uint256 claimableCollateral = call2880Payout + spreadCollateralAmount - call3520Payout;

        // mint the option to be used as collateral for the spread
        deal(address(WETH), user, call2880CollateralAmount, true);
        WETH.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenCall2880), optionsAmount);

        // mint the spread using the previously minted option as collateral
        controller.mintSpread(address(qTokenCall3520), address(qTokenCall2880), optionsAmount);

        // advance time and mock the option being expired Out of The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // claim the collateral from the expired spread
        controller.claimCollateral(spreadCTokenId, amountToClaim);

        // check balances
        assertEq(WETH.balanceOf(user), claimableCollateral);
        assertEq(WETH.balanceOf(address(controller)), totalRequiredCollateral - claimableCollateral);
        assertEq(qTokenCall3520.balanceOf(user), optionsAmount);
        assertEq(qTokenCall2880.balanceOf(user), 0);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall2880), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall3520), 0);
        assertEq(collateralToken.balanceOf(user, spreadCTokenId), optionsAmount - amountToClaim);

        vm.warp(initialBlockTimestamp);

        vm.stopPrank();
    }
}
