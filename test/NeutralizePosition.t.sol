// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import "./ControllerTestBase.sol";

contract NeutralizePositionTest is ControllerTestBase {
    function testCannotNeutralizeWithNoBalance() public {
        vm.expectRevert(stdError.arithmeticError);
        controller.neutralizePosition(cTokenIdXCall, 1 ether);
    }

    function testCannotNeutralizeMoreThanBalance() public {
        vm.startPrank(user);

        uint256 amountToMint = 2 ether;
        uint256 amountToNeutralize = 3 ether;

        deal(address(WBNB), user, amountToMint, true);
        WBNB.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenXCall), amountToMint);

        vm.expectRevert(stdError.arithmeticError);
        controller.neutralizePosition(cTokenIdXCall, amountToNeutralize);

        vm.stopPrank();
    }

    function testPartialPutNeutralization() public {
        vm.startPrank(user);

        uint256 optionsAmount = 5 ether;
        uint256 amountToNeutralize = 3 ether;
        uint256 remainingAmount = optionsAmount - amountToNeutralize;
        uint256 collateralAmount = qTokenPut1400.strikePrice() * 5;

        // mint the option to the user
        deal(address(BUSD), user, collateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut1400), optionsAmount);

        // neutralize part of the user's position
        controller.neutralizePosition(cTokenIdPut1400, amountToNeutralize);

        // check balances
        assertEq(qTokenPut1400.balanceOf(user), remainingAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut1400), remainingAmount);

        assertEq(BUSD.balanceOf(user), qTokenPut1400.strikePrice() * 3);
        assertEq(BUSD.balanceOf(address(controller)), qTokenPut1400.strikePrice() * 2);

        vm.stopPrank();
    }

    function testFullPutNeutralization() public {
        vm.startPrank(user);

        uint256 optionsAmount = 5 ether;
        uint256 amountToNeutralize = optionsAmount;
        uint256 remainingAmount = optionsAmount - amountToNeutralize;
        uint256 collateralAmount = qTokenPut1400.strikePrice() * 5;

        // mint the option to the user
        deal(address(BUSD), user, collateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut1400), optionsAmount);

        // neutralize all of the user's position
        controller.neutralizePosition(cTokenIdPut1400, amountToNeutralize);

        // check balances
        assertEq(qTokenPut1400.balanceOf(user), remainingAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut1400), remainingAmount);

        assertEq(BUSD.balanceOf(user), collateralAmount);
        assertEq(BUSD.balanceOf(address(controller)), 0);

        vm.stopPrank();
    }

    function testPartialCallNeutralization() public {
        vm.startPrank(user);

        uint256 optionsAmount = 7 ether;
        uint256 amountToNeutralize = 4 ether;
        uint256 remainingAmount = optionsAmount - amountToNeutralize;
        uint256 collateralAmount = optionsAmount;

        // mint the option to the user
        deal(address(WETH), user, collateralAmount, true);
        WETH.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenCall3520), optionsAmount);

        // neutralize some of the user's position
        controller.neutralizePosition(cTokenIdCall3520, amountToNeutralize);

        // check balances
        assertEq(qTokenCall3520.balanceOf(user), remainingAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall3520), remainingAmount);

        assertEq(WETH.balanceOf(user), 4 ether);
        assertEq(WETH.balanceOf(address(controller)), 3 ether);

        vm.stopPrank();
    }

    function testFullCallNeutralization() public {
        vm.startPrank(user);

        uint256 optionsAmount = 3 ether;
        uint256 amountToNeutralize = optionsAmount;
        uint256 remainingAmount = optionsAmount - amountToNeutralize;
        uint256 collateralAmount = optionsAmount;

        // mint the option to the user
        deal(address(WETH), user, collateralAmount, true);
        WETH.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenCall3520), optionsAmount);

        // neutralize some of the user's position
        controller.neutralizePosition(cTokenIdCall3520, amountToNeutralize);

        // check balances
        assertEq(qTokenCall3520.balanceOf(user), remainingAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall3520), remainingAmount);

        assertEq(WETH.balanceOf(user), collateralAmount);
        assertEq(WETH.balanceOf(address(controller)), 0);

        vm.stopPrank();
    }

    function testPartialPutCreditSpreadNeutralization() public {
        vm.startPrank(user);

        uint256 optionsAmount = 5 ether;
        uint256 amountToNeutralize = 3 ether;
        uint256 put400CollateralAmount = qTokenPut400.strikePrice() * 5;
        uint256 put1400CollateralAmount = qTokenPut1400.strikePrice() * 5;
        uint256 spreadCollateralAmount = put1400CollateralAmount - put400CollateralAmount;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenPut1400), address(qTokenPut400));
        uint256 collateralReturned = (qTokenPut1400.strikePrice() - qTokenPut400.strikePrice()) * 3;

        // mint the option to be used as collateral for the spread
        deal(address(BUSD), user, put400CollateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut400), optionsAmount);

        // mint the spread using the previously minted option as collateral
        deal(address(BUSD), user, spreadCollateralAmount, true);
        controller.mintSpread(address(qTokenPut1400), address(qTokenPut400), optionsAmount);

        // neutralize part of the user's spread
        controller.neutralizePosition(spreadCTokenId, amountToNeutralize);

        // check balances
        assertEq(qTokenPut1400.balanceOf(user), 2 ether);
        assertEq(qTokenPut400.balanceOf(user), 3 ether);

        assertEq(collateralToken.balanceOf(user, spreadCTokenId), 2 ether);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut1400), 0);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut400), optionsAmount);

        assertEq(BUSD.balanceOf(address(controller)), put1400CollateralAmount - collateralReturned);
        assertEq(BUSD.balanceOf(user), collateralReturned);

        vm.stopPrank();
    }

    function testFullPutCreditSpreadNeutralization() public {
        vm.startPrank(user);

        uint256 optionsAmount = 5 ether;
        uint256 amountToNeutralize = optionsAmount;
        uint256 put400CollateralAmount = qTokenPut400.strikePrice() * 5;
        uint256 put1400CollateralAmount = qTokenPut1400.strikePrice() * 5;
        uint256 spreadCollateralAmount = put1400CollateralAmount - put400CollateralAmount;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenPut1400), address(qTokenPut400));
        uint256 collateralReturned = spreadCollateralAmount;

        // mint the option to be used as collateral for the spread
        deal(address(BUSD), user, put400CollateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut400), optionsAmount);

        // mint the spread using the previously minted option as collateral
        deal(address(BUSD), user, spreadCollateralAmount, true);
        controller.mintSpread(address(qTokenPut1400), address(qTokenPut400), optionsAmount);

        // neutralize all of the user's spread
        controller.neutralizePosition(spreadCTokenId, amountToNeutralize);

        // check balances
        assertEq(qTokenPut1400.balanceOf(user), 0);
        assertEq(qTokenPut400.balanceOf(user), optionsAmount);

        assertEq(collateralToken.balanceOf(user, spreadCTokenId), 0);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut1400), 0);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut400), optionsAmount);

        assertEq(BUSD.balanceOf(address(controller)), put1400CollateralAmount - collateralReturned);
        assertEq(BUSD.balanceOf(user), collateralReturned);

        vm.stopPrank();
    }

    function testPartialPutDebitSpreadNeutralization() public {
        vm.startPrank(user);

        uint256 optionsAmount = 3 ether;
        uint256 amountToNeutralize = 1 ether;
        uint256 remainingAmount = optionsAmount - amountToNeutralize;
        uint256 put1400CollateralAmount = qTokenPut1400.strikePrice() * 3;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenPut400), address(qTokenPut1400));

        // mint the option to be used as collateral for the spread
        deal(address(BUSD), user, put1400CollateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut1400), optionsAmount);

        // mint the spread using the previously minted option as collateral
        controller.mintSpread(address(qTokenPut400), address(qTokenPut1400), optionsAmount);

        // neutralize some of the user's spread
        controller.neutralizePosition(spreadCTokenId, amountToNeutralize);

        // check balances
        assertEq(qTokenPut1400.balanceOf(user), amountToNeutralize);
        assertEq(qTokenPut400.balanceOf(user), remainingAmount);

        assertEq(collateralToken.balanceOf(user, spreadCTokenId), remainingAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut1400), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut400), 0);

        assertEq(BUSD.balanceOf(address(controller)), put1400CollateralAmount);
        assertEq(BUSD.balanceOf(user), 0);

        vm.stopPrank();
    }

    function testFullPutDebitSpreadNeutralization() public {
        vm.startPrank(user);

        uint256 optionsAmount = 6 ether;
        uint256 amountToNeutralize = optionsAmount;
        uint256 remainingAmount = optionsAmount - amountToNeutralize;
        uint256 put1400CollateralAmount = qTokenPut1400.strikePrice() * 6;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenPut400), address(qTokenPut1400));

        // mint the option to be used as collateral for the spread
        deal(address(BUSD), user, put1400CollateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut1400), optionsAmount);

        // mint the spread using the previously minted option as collateral
        controller.mintSpread(address(qTokenPut400), address(qTokenPut1400), optionsAmount);

        // neutralize all of the user's spread
        controller.neutralizePosition(spreadCTokenId, amountToNeutralize);

        // check balances
        assertEq(qTokenPut1400.balanceOf(user), amountToNeutralize);
        assertEq(qTokenPut400.balanceOf(user), remainingAmount);

        assertEq(collateralToken.balanceOf(user, spreadCTokenId), 0);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut1400), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut400), 0);

        assertEq(BUSD.balanceOf(address(controller)), put1400CollateralAmount);
        assertEq(BUSD.balanceOf(user), 0);

        vm.stopPrank();
    }

    function testPartialCallCreditSpreadNeutralization() public {
        vm.startPrank(user);

        uint256 optionsAmount = 7 ether;
        uint256 amountToNeutralize = 4 ether;
        uint256 remainingAmount = optionsAmount - amountToNeutralize;
        uint256 call3520CollateralAmount = optionsAmount;
        uint256 spreadCollateralAmount = 1272727272727272728;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenCall2880), address(qTokenCall3520));
        uint256 collateralReturned = spreadCollateralAmount * 4 / 7 - 1; // round down

        // mint the option to be used as collateral for the spread
        deal(address(WETH), user, call3520CollateralAmount, true);
        WETH.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenCall3520), optionsAmount);

        // mint the spread using the previously minted option as collateral
        deal(address(WETH), user, spreadCollateralAmount, true);
        controller.mintSpread(address(qTokenCall2880), address(qTokenCall3520), optionsAmount);

        // neutralize some of the user's spread
        controller.neutralizePosition(spreadCTokenId, amountToNeutralize);

        // check balances
        assertEq(qTokenCall3520.balanceOf(user), amountToNeutralize);
        assertEq(qTokenCall2880.balanceOf(user), remainingAmount);

        assertEq(collateralToken.balanceOf(user, spreadCTokenId), remainingAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall3520), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall2880), 0);

        assertEq(WETH.balanceOf(address(controller)), optionsAmount + spreadCollateralAmount - collateralReturned);
        assertEq(WETH.balanceOf(user), collateralReturned);

        vm.stopPrank();
    }

    function testFullCallCreditSpreadNeutralization() public {
        vm.startPrank(user);

        uint256 optionsAmount = 13 ether;
        uint256 amountToNeutralize = optionsAmount;
        uint256 remainingAmount = optionsAmount - amountToNeutralize;
        uint256 call3520CollateralAmount = optionsAmount;
        uint256 spreadCollateralAmount = 2363636363636363637;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenCall2880), address(qTokenCall3520));

        // mint the option to be used as collateral for the spread
        deal(address(WETH), user, call3520CollateralAmount, true);
        WETH.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenCall3520), optionsAmount);

        // mint the spread using the previously minted option as collateral
        deal(address(WETH), user, spreadCollateralAmount, true);
        controller.mintSpread(address(qTokenCall2880), address(qTokenCall3520), optionsAmount);

        // neutralize all of the user's spread
        controller.neutralizePosition(spreadCTokenId, amountToNeutralize);

        // check balances
        assertEq(qTokenCall3520.balanceOf(user), amountToNeutralize);
        assertEq(qTokenCall2880.balanceOf(user), remainingAmount);

        assertEq(collateralToken.balanceOf(user, spreadCTokenId), remainingAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall3520), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall2880), 0);

        assertEq(WETH.balanceOf(address(controller)), optionsAmount + 1); // round up
        assertEq(WETH.balanceOf(user), spreadCollateralAmount - 1); // round down

        vm.stopPrank();
    }

    function testCallNeutralizeWithZeroAmount() public {
        vm.startPrank(user);

        uint256 optionsAmount = 7 ether;
        uint256 remainingAmount = 0;
        uint256 collateralAmount = optionsAmount;

        // mint the option to the user
        deal(address(WETH), user, collateralAmount, true);
        WETH.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenCall3520), optionsAmount);

        // neutralize all of the user's position, passing 0 as the amount to neutralize
        controller.neutralizePosition(cTokenIdCall3520, 0);

        // check balances
        assertEq(qTokenCall3520.balanceOf(user), remainingAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall3520), remainingAmount);

        assertEq(WETH.balanceOf(user), collateralAmount);
        assertEq(WETH.balanceOf(address(controller)), 0);

        vm.stopPrank();
    }
}
