// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import "./ControllerTestBase.sol";

contract MintOptionsPositionTest is ControllerTestBase {
    function testCannotMintOptionWithDeactivatedOracle() public {
        address deactivatedOracle = 0x35A47A648c72Ab9B68512c4651cFdE8672432D6A;

        vm.mockCall(
            deactivatedOracle,
            abi.encodeWithSelector(bytes4(keccak256(bytes("isValidOption(address,uint88,uint256)")))),
            abi.encode(true)
        );

        (address qTokenAddress, uint256 cTokenId) = optionsFactory.createOption(
            address(WBNB), deactivatedOracle, uint88(block.timestamp + 604800), true, 500 ether
        );

        vm.mockCall(
            oracleRegistry,
            abi.encodeWithSelector(bytes4(keccak256(bytes("isOracleActive(address)"))), deactivatedOracle),
            abi.encode(false)
        );

        vm.expectRevert(bytes("Controller: Can't mint an options position as the oracle is inactive"));
        controller.mintOptionsPosition(address(this), qTokenAddress, 1 ether);
    }

    function testCannotMintNonExistentOption() public {
        address notAQtoken = 0x248B0fbeb55d4b2Ba9b4A47c1e9B8fE1B78BE6bb;

        vm.expectRevert(bytes("QuantCalculator: Invalid QToken address"));
        controller.mintOptionsPosition(address(this), notAQtoken, 2 ether);
    }

    function testCannotMintExpiredOption() public {
        uint256 initialBlockTimestamp = block.timestamp;

        // set block.timestamp to one hour past the expiry
        vm.warp(expiryTimestamp + 3600);

        vm.expectRevert(bytes("Controller: Cannot mint expired options"));
        controller.mintOptionsPosition(address(this), address(qTokenXCall), 3 ether);

        // reset the block.timestamp to its initial value
        vm.warp(initialBlockTimestamp);
    }

    function testMintCallOptionsToSenderAddress() public {
        vm.startPrank(user);

        uint256 optionsAmount = 1 ether;
        uint256 collateralAmount = optionsAmount;
        address collateral = address(WBNB);

        // make sure the user has enough collateral and that he approves the Controller to spend it
        deal(collateral, user, collateralAmount, true);
        ERC20(collateral).approve(address(controller), type(uint256).max);

        // mint the options to the user(sender) address
        controller.mintOptionsPosition(user, address(qTokenXCall), optionsAmount);

        // check the balances after minting
        assertEq(ERC20(collateral).balanceOf(user), 0);
        assertEq(ERC20(collateral).balanceOf(address(controller)), collateralAmount);
        assertEq(qTokenXCall.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdXCall), optionsAmount);

        vm.stopPrank();
    }

    function testMintPutOptionsToSenderAddress() public {
        vm.startPrank(user);

        uint256 optionsAmount = 1 ether;
        uint256 collateralAmount = qTokenXPut.strikePrice();
        address collateral = address(BUSD);

        // make sure the user has enough collateral and that he approves the Controller to spend it
        deal(collateral, user, collateralAmount, true);
        ERC20(collateral).approve(address(controller), type(uint256).max);

        // mint the options to the user(sender) address
        controller.mintOptionsPosition(user, address(qTokenXPut), optionsAmount);

        // check the balances after minting
        assertEq(ERC20(collateral).balanceOf(user), 0);
        assertEq(ERC20(collateral).balanceOf(address(controller)), collateralAmount);
        assertEq(qTokenXPut.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdXPut), optionsAmount);

        vm.stopPrank();
    }

    function testMintCallOptionsToOtherAddress() public {
        vm.startPrank(user);

        uint256 optionsAmount = 1 ether;
        uint256 collateralAmount = optionsAmount;
        address collateral = address(WBNB);

        // make sure the user has enough collateral and that he approves the Controller to spend it
        deal(collateral, user, collateralAmount, true);
        ERC20(collateral).approve(address(controller), type(uint256).max);

        // mint the options to a different account than the sender
        controller.mintOptionsPosition(secondaryAccount, address(qTokenXCall), optionsAmount);

        // check the balances after minting
        assertEq(ERC20(collateral).balanceOf(user), 0);
        assertEq(ERC20(collateral).balanceOf(address(controller)), collateralAmount);

        // confirm that the specified receiver address got all of the option tokens
        assertEq(qTokenXCall.balanceOf(secondaryAccount), optionsAmount);
        assertEq(collateralToken.balanceOf(secondaryAccount, cTokenIdXCall), optionsAmount);

        // confirm that the sender/options minter didn't get any of the option tokens
        assertEq(qTokenXCall.balanceOf(user), 0);
        assertEq(collateralToken.balanceOf(user, cTokenIdXCall), 0);

        vm.stopPrank();
    }

    function testMintPutOptionsToOtherAddress() public {
        vm.startPrank(user);

        uint256 optionsAmount = 1 ether;
        uint256 collateralAmount = qTokenXPut.strikePrice();
        address collateral = address(BUSD);

        // make sure the user has enough collateral and that he approves the Controller to spend it
        deal(collateral, user, collateralAmount, true);
        ERC20(collateral).approve(address(controller), type(uint256).max);

        // mint the options to a different account than the sender
        controller.mintOptionsPosition(secondaryAccount, address(qTokenXPut), optionsAmount);

        // check the balances after minting
        assertEq(ERC20(collateral).balanceOf(user), 0);
        assertEq(ERC20(collateral).balanceOf(address(controller)), collateralAmount);

        // confirm that the specified receiver address got all of the option tokens
        assertEq(qTokenXPut.balanceOf(secondaryAccount), optionsAmount);
        assertEq(collateralToken.balanceOf(secondaryAccount, cTokenIdXPut), optionsAmount);

        // confirm that the sender/options minter didn't get any of the option tokens
        assertEq(qTokenXPut.balanceOf(user), 0);
        assertEq(collateralToken.balanceOf(user, cTokenIdXPut), 0);

        vm.stopPrank();
    }
}
