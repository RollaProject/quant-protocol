// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import "./ControllerTestBase.sol";

contract MintSpreadTest is ControllerTestBase {
    function testCannotMintSpreadWithDifferentOracles() public {
        address secondOracle = 0xCFd6FeEF5765B07e144C4630C37ca56b229999C2;
        vm.mockCall(
            secondOracle,
            abi.encodeWithSelector(bytes4(keccak256(bytes("isValidOption(address,uint88,uint256)")))),
            abi.encode(true)
        );

        (address secondOption,) =
            optionsFactory.createOption(address(WBNB), secondOracle, expiryTimestamp, true, 600 ether);

        vm.expectRevert(bytes("Controller: Can't create spreads from options with different oracles"));

        controller.mintSpread(address(qTokenXCall), secondOption, 1 ether);
    }

    function testCannotCreateSpreadWithDeactivatedOracle() public {
        address deactivatedOracle = 0x35A47A648c72Ab9B68512c4651cFdE8672432D6A;

        vm.mockCall(
            deactivatedOracle,
            abi.encodeWithSelector(bytes4(keccak256(bytes("isValidOption(address,uint88,uint256)")))),
            abi.encode(true)
        );

        (address qTokenA,) =
            optionsFactory.createOption(address(WBNB), deactivatedOracle, expiryTimestamp, true, 500 ether);

        (address qTokenB,) =
            optionsFactory.createOption(address(WBNB), deactivatedOracle, expiryTimestamp, true, 600 ether);

        vm.mockCall(
            oracleRegistry,
            abi.encodeWithSelector(bytes4(keccak256(bytes("isOracleActive(address)"))), deactivatedOracle),
            abi.encode(false)
        );

        vm.expectRevert(bytes("Controller: Can't mint an options position as the oracle is inactive"));

        controller.mintSpread(qTokenA, qTokenB, 2 ether);
    }

    function testCannotMintSpreadWithZeroAddressAsCollateral() public {
        vm.expectRevert(bytes(""));
        controller.mintSpread(address(qTokenXCall), address(0), 3 ether);
    }

    function testCannotMintSpreadWithDifferentExpiries() public {
        uint88 diffExpiryTimestamp = expiryTimestamp + 3600;

        (address qTokenDiffExpiry,) =
            optionsFactory.createOption(address(WBNB), oracle, diffExpiryTimestamp, true, 650 ether);

        vm.expectRevert(bytes("Controller: Can't create spreads from options with different expiries"));

        controller.mintSpread(address(qTokenXCall), qTokenDiffExpiry, 4 ether);
    }

    function testCannotMintSpreadWithDifferentUnderlying() public {
        vm.expectRevert(bytes("Controller: Can't create spreads from options with different underlying assets"));

        controller.mintSpread(address(qTokenXCall), address(qTokenYCall), 5 ether);
    }

    function testCannotMintSpreadWithSameQToken() public {
        vm.expectRevert(bytes("Controller: Can only create a spread with different tokens"));

        controller.mintSpread(address(qTokenXCall), address(qTokenXCall), 6 ether);
    }

    function testCannotMintSpreadWithDifferentOptionType() public {
        vm.expectRevert(bytes("Controller: Can't create spreads from options with different types"));

        controller.mintSpread(address(qTokenXCall), address(qTokenXPut), 7 ether);
    }

    function testMintPutCreditSpread() public {
        vm.startPrank(user);

        uint256 optionsAmount = 1 ether;
        address collateral = address(BUSD);
        uint256 put400CollateralAmount = qTokenPut400.strikePrice();
        uint256 put1400CollateralAmount = qTokenPut1400.strikePrice();
        uint256 spreadCollateralAmount = put1400CollateralAmount - put400CollateralAmount;
        uint256 totalRequiredCollateral = put1400CollateralAmount;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenPut1400), address(qTokenPut400));

        // mint the option to be used as collateral for the spread
        deal(collateral, user, put400CollateralAmount, true);
        ERC20(collateral).approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut400), optionsAmount);

        // mint the spread using the previously minted option as collateral
        deal(collateral, user, spreadCollateralAmount, true);
        controller.mintSpread(address(qTokenPut1400), address(qTokenPut400), optionsAmount);

        // check balances
        assertEq(ERC20(collateral).balanceOf(address(controller)), totalRequiredCollateral);
        assertEq(ERC20(collateral).balanceOf(user), 0);

        assertEq(qTokenPut400.balanceOf(user), 0);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut400), optionsAmount);

        assertEq(qTokenPut1400.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, spreadCTokenId), optionsAmount);

        vm.stopPrank();
    }

    function testMintPutDebitSpread() public {
        vm.startPrank(user);

        uint256 optionsAmount = 2 ether;
        address collateral = address(BUSD);
        uint256 put1400CollateralAmount = qTokenPut1400.strikePrice() * 2;
        uint256 totalRequiredCollateral = put1400CollateralAmount;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenPut400), address(qTokenPut1400));

        // mint the option to be used as collateral for the spread
        deal(collateral, user, put1400CollateralAmount, true);
        ERC20(collateral).approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut1400), optionsAmount);

        // mint the spread using the previously minted option as collateral
        controller.mintSpread(address(qTokenPut400), address(qTokenPut1400), optionsAmount);

        // check balances
        assertEq(ERC20(collateral).balanceOf(address(controller)), totalRequiredCollateral);
        assertEq(ERC20(collateral).balanceOf(user), 0);

        assertEq(qTokenPut1400.balanceOf(user), 0);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut1400), optionsAmount);

        assertEq(qTokenPut400.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, spreadCTokenId), optionsAmount);

        vm.stopPrank();
    }

    function testMintCallCreditSpread() public {
        vm.startPrank(user);

        uint256 optionsAmount = 3 ether;
        address collateral = address(WETH);
        uint256 call3520CollateralAmount = optionsAmount;

        uint256 spreadCollateralAmount = 545454545454545455;

        uint256 totalRequiredCollateral = call3520CollateralAmount + spreadCollateralAmount;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenCall2880), address(qTokenCall3520));

        // mint the option to be used as collateral for the spread
        deal(collateral, user, call3520CollateralAmount, true);
        ERC20(collateral).approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenCall3520), optionsAmount);

        // mint the spread using the previously minted option as collateral
        deal(collateral, user, spreadCollateralAmount, true);
        controller.mintSpread(address(qTokenCall2880), address(qTokenCall3520), optionsAmount);

        // check balances
        assertEq(ERC20(collateral).balanceOf(address(controller)), totalRequiredCollateral);
        assertEq(ERC20(collateral).balanceOf(user), 0);

        assertEq(qTokenCall3520.balanceOf(user), 0);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall3520), optionsAmount);

        assertEq(qTokenCall2880.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, spreadCTokenId), optionsAmount);

        vm.stopPrank();
    }

    function testMintCallDebitSpread() public {
        vm.startPrank(user);

        uint256 optionsAmount = 4 ether;
        address collateral = address(WETH);
        uint256 call2880CollateralAmount = optionsAmount;
        uint256 totalRequiredCollateral = call2880CollateralAmount;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenCall3520), address(qTokenCall2880));

        // mint the option to be used as collateral for the spread
        deal(collateral, user, call2880CollateralAmount, true);
        ERC20(collateral).approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenCall2880), optionsAmount);

        // mint the spread using the previously minted option as collateral
        controller.mintSpread(address(qTokenCall3520), address(qTokenCall2880), optionsAmount);

        // check balances
        assertEq(ERC20(collateral).balanceOf(address(controller)), totalRequiredCollateral);
        assertEq(ERC20(collateral).balanceOf(user), 0);

        assertEq(qTokenCall2880.balanceOf(user), 0);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall2880), optionsAmount);

        assertEq(qTokenCall3520.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, spreadCTokenId), optionsAmount);

        vm.stopPrank();
    }

    function testCreateSpreadCollateralTokenBeforehand() public {
        uint256 optionsAmount = 6 ether;
        address collateral = address(WETH);
        uint256 call2880CollateralAmount = optionsAmount;
        uint256 totalRequiredCollateral = call2880CollateralAmount;
        address qTokenAsCollateral;
        uint256 spreadCTokenId;

        spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenCall3520), address(qTokenCall2880));

        (, qTokenAsCollateral) = collateralToken.idToInfo(spreadCTokenId);
        assertEq(qTokenAsCollateral, address(0));

        // simulate the spread CollateralToken having already been created by the Controller
        // (e.g., when another user minted the same spread beforehand)
        vm.prank(address(controller)); // only the Controller can create CollateralTokens
        spreadCTokenId = collateralToken.createSpreadCollateralToken(address(qTokenCall3520), address(qTokenCall2880));

        (, qTokenAsCollateral) = collateralToken.idToInfo(spreadCTokenId);
        assertEq(qTokenAsCollateral, address(qTokenCall2880));

        vm.startPrank(user);

        // mint the option to be used as collateral for the spread
        deal(collateral, user, call2880CollateralAmount, true);
        ERC20(collateral).approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenCall2880), optionsAmount);

        // mint the spread using the previously minted option as collateral
        controller.mintSpread(address(qTokenCall3520), address(qTokenCall2880), optionsAmount);

        // check balances
        assertEq(ERC20(collateral).balanceOf(address(controller)), totalRequiredCollateral);
        assertEq(ERC20(collateral).balanceOf(user), 0);

        assertEq(qTokenCall2880.balanceOf(user), 0);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall2880), optionsAmount);

        assertEq(qTokenCall3520.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, spreadCTokenId), optionsAmount);

        vm.stopPrank();
    }
}
