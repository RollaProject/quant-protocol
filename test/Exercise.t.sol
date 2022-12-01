// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

import "./ControllerTestBase.sol";
import {ExternalQToken} from "../src/mocks/ExternalQToken.sol";
import {SimpleExternalOptionsFactory} from "../src/mocks/SimpleExternalOptionsFactory.sol";

contract ExerciseTest is ControllerTestBase {
    function testCannotExerciseInvalidOption() public {
        address notAnOption = address(17847);
        vm.expectRevert();
        controller.exercise(notAnOption, 100 ether);
    }

    function testCannotExerciseOptionBeforeExpiry() public {
        vm.expectRevert(bytes("Controller: Can not exercise options before their expiry"));
        controller.exercise(address(qTokenPut1400), 1 ether);
    }

    function testCannotExerciseOptionBeforeSettlement() public {
        vm.warp(expiryTimestamp + 3600);

        vm.mockCall(priceRegistry, abi.encodeWithSelector(IPriceRegistry.hasSettlementPrice.selector), abi.encode(true));
        vm.mockCall(
            priceRegistry,
            abi.encodeWithSelector(IPriceRegistry.getOptionPriceStatus.selector, oracle, expiryTimestamp, address(WETH)),
            abi.encode(PriceStatus.AWAITING_SETTLEMENT_PRICE)
        );

        vm.expectRevert(bytes("Controller: Cannot exercise unsettled options"));
        controller.exercise(address(qTokenPut1400), 2 ether);
    }

    function testCannotExerciseOptionDuringDisputePeriod() public {
        vm.warp(expiryTimestamp + 3600);

        vm.mockCall(priceRegistry, abi.encodeWithSelector(IPriceRegistry.hasSettlementPrice.selector), abi.encode(true));
        vm.mockCall(
            priceRegistry,
            abi.encodeWithSelector(IPriceRegistry.getOptionPriceStatus.selector, oracle, expiryTimestamp, address(WETH)),
            abi.encode(PriceStatus.DISPUTABLE)
        );

        vm.expectRevert(bytes("Controller: Cannot exercise unsettled options"));
        controller.exercise(address(qTokenPut1400), 2 ether);
    }

    function testExerciseITMPut() public {
        vm.startPrank(user);

        QToken qTokenToExercise = qTokenPut1400;
        uint256 expiryPrice = 1200 ether;
        uint256 amountMultiplier = 1;
        uint256 optionsAmount = amountMultiplier * 1 ether;
        uint256 collateralAmount = qTokenToExercise.strikePrice() * amountMultiplier;
        uint256 exercisePayout = qTokenToExercise.strikePrice() > expiryPrice
            ? (qTokenToExercise.strikePrice() - expiryPrice) * amountMultiplier
            : 0;

        // mint the option to the user
        deal(address(BUSD), user, collateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenToExercise), optionsAmount);

        // advance time and mock the option being expired In The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);
        assertEq(BUSD.balanceOf(user), 0);

        // exercise the expired option
        controller.exercise(address(qTokenToExercise), optionsAmount);

        // check balances
        assertEq(qTokenToExercise.balanceOf(user), 0);
        assertEq(BUSD.balanceOf(user), exercisePayout);
        assertEq(BUSD.balanceOf(address(controller)), collateralAmount - exercisePayout);

        vm.stopPrank();
    }

    function testExerciseOTMPut() public {
        vm.startPrank(user);

        QToken qTokenToExercise = qTokenPut1400;
        uint256 expiryPrice = 1600 ether;
        uint256 amountMultiplier = 3;
        uint256 optionsAmount = amountMultiplier * 1 ether;
        uint256 collateralAmount = qTokenToExercise.strikePrice() * amountMultiplier;
        uint256 exercisePayout = qTokenToExercise.strikePrice() > expiryPrice
            ? (qTokenToExercise.strikePrice() - expiryPrice) * amountMultiplier
            : 0;

        // mint the option to the user
        deal(address(BUSD), user, collateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenToExercise), optionsAmount);

        // advance time and mock the option being expired Out of The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);
        assertEq(BUSD.balanceOf(user), 0);

        // exercise the expired option
        controller.exercise(address(qTokenToExercise), optionsAmount);

        // check balances
        assertEq(qTokenToExercise.balanceOf(user), 0);
        assertEq(BUSD.balanceOf(user), exercisePayout);
        assertEq(BUSD.balanceOf(address(controller)), collateralAmount - exercisePayout);

        vm.stopPrank();
    }

    function testExerciseATMPut() public {
        vm.startPrank(user);

        QToken qTokenToExercise = qTokenPut1400;
        uint256 expiryPrice = qTokenToExercise.strikePrice();
        uint256 amountMultiplier = 5;
        uint256 optionsAmount = amountMultiplier * 1 ether;
        uint256 collateralAmount = qTokenToExercise.strikePrice() * amountMultiplier;
        uint256 exercisePayout = qTokenToExercise.strikePrice() > expiryPrice
            ? (qTokenToExercise.strikePrice() - expiryPrice) * amountMultiplier
            : 0;

        // mint the option to the user
        deal(address(BUSD), user, collateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenToExercise), optionsAmount);

        // advance time and mock the option being expired At The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);
        assertEq(BUSD.balanceOf(user), 0);

        // exercise the expired option
        controller.exercise(address(qTokenToExercise), optionsAmount);

        // check balances
        assertEq(qTokenToExercise.balanceOf(user), 0);
        assertEq(BUSD.balanceOf(user), exercisePayout);
        assertEq(BUSD.balanceOf(address(controller)), collateralAmount - exercisePayout);

        vm.stopPrank();
    }

    function testExerciseITMCall() public {
        vm.startPrank(user);

        QToken qTokenToExercise = qTokenCall2000;
        uint256 expiryPrice = 2500 ether;
        uint256 amountMultiplier = 7;
        uint256 optionsAmount = amountMultiplier * 1 ether;
        uint256 collateralAmount = optionsAmount;
        uint256 exercisePayout = expiryPrice > qTokenToExercise.strikePrice()
            ? ((expiryPrice - qTokenToExercise.strikePrice()) * optionsAmount) / expiryPrice
            : 0;

        // mint the option to the user
        deal(address(WETH), user, collateralAmount, true);
        WETH.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenToExercise), optionsAmount);

        // advance time and mock the option being expired In The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);
        assertEq(BUSD.balanceOf(user), 0);

        // exercise the expired option
        controller.exercise(address(qTokenToExercise), optionsAmount);

        // check balances
        assertEq(qTokenToExercise.balanceOf(user), 0);
        assertEq(WETH.balanceOf(user), exercisePayout);
        assertEq(WETH.balanceOf(address(controller)), collateralAmount - exercisePayout);

        vm.stopPrank();
    }

    function testExerciseOTMCall() public {
        vm.startPrank(user);

        QToken qTokenToExercise = qTokenCall2000;
        uint256 expiryPrice = 1200 ether;
        uint256 amountMultiplier = 2;
        uint256 optionsAmount = amountMultiplier * 1 ether;
        uint256 collateralAmount = optionsAmount;
        uint256 exercisePayout = expiryPrice > qTokenToExercise.strikePrice()
            ? ((expiryPrice - qTokenToExercise.strikePrice()) * optionsAmount) / expiryPrice
            : 0;

        // mint the option to the user
        deal(address(WETH), user, collateralAmount, true);
        WETH.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenToExercise), optionsAmount);

        // advance time and mock the option being expired In The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);
        assertEq(BUSD.balanceOf(user), 0);

        // exercise the expired option
        controller.exercise(address(qTokenToExercise), optionsAmount);

        // check balances
        assertEq(qTokenToExercise.balanceOf(user), 0);
        assertEq(WETH.balanceOf(user), exercisePayout);
        assertEq(WETH.balanceOf(address(controller)), collateralAmount - exercisePayout);

        vm.stopPrank();
    }

    function testExerciseATMCall() public {
        vm.startPrank(user);

        QToken qTokenToExercise = qTokenCall2000;
        uint256 expiryPrice = qTokenToExercise.strikePrice();
        uint256 amountMultiplier = 8;
        uint256 optionsAmount = amountMultiplier * 1 ether;
        uint256 collateralAmount = optionsAmount;
        uint256 exercisePayout = expiryPrice > qTokenToExercise.strikePrice()
            ? ((expiryPrice - qTokenToExercise.strikePrice()) * optionsAmount) / expiryPrice
            : 0;

        // mint the option to the user
        deal(address(WETH), user, collateralAmount, true);
        WETH.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenToExercise), optionsAmount);

        // advance time and mock the option being expired In The Money
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);
        assertEq(BUSD.balanceOf(user), 0);

        // exercise the expired option
        controller.exercise(address(qTokenToExercise), optionsAmount);

        // check balances
        assertEq(qTokenToExercise.balanceOf(user), 0);
        assertEq(WETH.balanceOf(user), exercisePayout);
        assertEq(WETH.balanceOf(address(controller)), collateralAmount - exercisePayout);

        vm.stopPrank();
    }

    function testCannotExerciseFakeExternalQTokens() public {
        uint256 optionsAmount = 15 ether;
        QToken firstRealQToken = qTokenPut1400;
        QToken secondRealQToken = qTokenPut400;
        uint256 firstCollateralAmount = firstRealQToken.strikePrice() * 15;
        uint256 secondCollateralAmount = secondRealQToken.strikePrice() * 15;
        uint256 totalCollateralAmount = firstCollateralAmount + secondCollateralAmount;

        // simulate some user minting real options through the Controller
        // (i.e., QTokens that were created with the OptionsFactory createOption method)
        vm.startPrank(user);

        ActionArgs[] memory mintActions = new ActionArgs[](2);

        mintActions[0] = ActionArgs({
            actionType: ActionType.MintOption,
            qToken: address(firstRealQToken),
            secondaryAddress: address(0),
            receiver: user,
            amount: optionsAmount,
            secondaryUint: 0,
            data: ""
        });

        mintActions[1] = ActionArgs({
            actionType: ActionType.MintOption,
            qToken: address(secondRealQToken),
            secondaryAddress: address(0),
            receiver: user,
            amount: optionsAmount,
            secondaryUint: 0,
            data: ""
        });

        deal(address(BUSD), user, totalCollateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.operate(mintActions);

        vm.stopPrank();

        // now we simulate the first option (PUT 1400) expiring ITM
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), 800 ether);

        // a malicious user now comes and deploy a contract that adheres to the IQToken interface,
        // or that simply inherits from the QToken contract
        address maliciousUser = address(1337404);
        vm.startPrank(maliciousUser);
        uint256 maliciousStrikePrice = 2600 ether;
        ExternalQToken maliciousQTokenImplementation = new ExternalQToken();
        SimpleExternalOptionsFactory maliciousOptionsFactory =
        new SimpleExternalOptionsFactory(address(assetsRegistry), address(maliciousQTokenImplementation), address(BUSD), address(controller));
        (address maliciousQToken,) = maliciousOptionsFactory.createOption(
            firstRealQToken.underlyingAsset(),
            firstRealQToken.oracle(),
            firstRealQToken.expiryTime(),
            firstRealQToken.isCall(),
            maliciousStrikePrice
        );

        // he then mints some of his new, malicious QToken
        ExternalQToken(maliciousQToken).permissionlessMint(maliciousUser, optionsAmount);

        // the malicious user should not be able to exercise his fake/external QToken
        vm.expectRevert("QuantCalculator: Invalid QToken address");
        controller.exercise(maliciousQToken, optionsAmount);
        vm.stopPrank();

        // confirm that all the legitimate balances are still in place
        assertEq(firstRealQToken.balanceOf(user), optionsAmount);
        assertEq(secondRealQToken.balanceOf(user), optionsAmount);
        assertEq(BUSD.balanceOf(user), 0);
        assertEq(BUSD.balanceOf(address(controller)), totalCollateralAmount);
    }
}
