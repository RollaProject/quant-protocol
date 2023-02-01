// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./ControllerTestBase.sol";

contract ControllerActionsTest is ControllerTestBase {
    function testMintOptionAction() public {
        vm.startPrank(user);

        uint256 optionsAmount = 3 ether;
        deal(address(WETH), user, optionsAmount, true);
        WETH.approve(address(controller), type(uint256).max);

        // get an array with the action to mint an option
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({
            actionType: ActionType.MintOption,
            qToken: address(qTokenCall2000),
            secondaryAddress: address(0),
            receiver: user,
            amount: optionsAmount,
            secondaryUint: 0,
            data: ""
        });

        // have the Controller execute the MintOption action
        controller.operate(actions);

        // check balances
        assertEq(WETH.balanceOf(user), 0);
        assertEq(WETH.balanceOf(address(controller)), optionsAmount);
        assertEq(qTokenCall2000.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall2000), optionsAmount);

        vm.stopPrank();
    }

    function testMintSpreadAction() public {
        vm.startPrank(user);

        uint256 amountMultiplier = 5;
        uint256 optionsAmount = amountMultiplier * 1 ether;
        uint256 collateralAmount = qTokenPut1400.strikePrice() * amountMultiplier;
        uint256 spreadCTokenId = collateralToken.getCollateralTokenId(address(qTokenPut400), address(qTokenPut1400));

        // mint the option to be used as collateral for the spread
        deal(address(BUSD), user, collateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut1400), optionsAmount);

        // get an array with the action mint a spread
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({
            actionType: ActionType.MintSpread,
            qToken: address(qTokenPut400),
            secondaryAddress: address(qTokenPut1400),
            receiver: address(0),
            amount: optionsAmount,
            secondaryUint: 0,
            data: ""
        });

        // have the Controller execute the MintSpread action
        controller.operate(actions);

        // check balances
        assertEq(BUSD.balanceOf(address(controller)), collateralAmount);
        assertEq(BUSD.balanceOf(user), 0);

        assertEq(qTokenPut1400.balanceOf(user), 0);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut1400), optionsAmount);

        assertEq(qTokenPut400.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, spreadCTokenId), optionsAmount);

        vm.stopPrank();
    }

    function testExerciseAction() public {
        vm.startPrank(user);

        uint256 expiryPrice = 1200 ether;
        uint256 amountMultiplier = 3;
        uint256 optionsAmount = amountMultiplier * 1 ether;
        uint256 collateralAmount = qTokenPut1400.strikePrice() * amountMultiplier;
        uint256 exercisePayout = (qTokenPut1400.strikePrice() - expiryPrice) * amountMultiplier;

        // mint the option to the user
        deal(address(BUSD), user, collateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut1400), optionsAmount);

        // advance time and mock the option being expired ITM
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // get an array with the action to exercise the option
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({
            actionType: ActionType.Exercise,
            qToken: address(qTokenPut1400),
            secondaryAddress: address(0),
            receiver: address(0),
            amount: 0, // exercise the whole position
            secondaryUint: 0,
            data: ""
        });

        // have the controller execute the Exercise action
        controller.operate(actions);

        // check balances
        assertEq(qTokenPut1400.balanceOf(user), 0);
        assertEq(BUSD.balanceOf(user), exercisePayout);
        assertEq(BUSD.balanceOf(address(controller)), collateralAmount - exercisePayout);

        vm.stopPrank();
    }

    function testClaimCollateralAction() public {
        vm.startPrank(user);

        uint256 expiryPrice = 300 ether;
        uint256 optionsAmount = 1 ether;
        uint256 amountToClaim = optionsAmount;
        uint256 collateralAmount = qTokenPut400.strikePrice();
        uint256 claimableCollateral = expiryPrice;

        // mint the option to the user
        deal(address(BUSD), user, collateralAmount, true);
        BUSD.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenPut400), optionsAmount);

        // advance time and mock the option being expired ITM
        vm.warp(expiryTimestamp + 3600);
        expireAndSettleOption(oracle, expiryTimestamp, address(WETH), expiryPrice);

        // get an array with the action to claim collateral
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({
            actionType: ActionType.ClaimCollateral,
            qToken: address(0),
            secondaryAddress: address(0),
            receiver: address(0),
            amount: amountToClaim,
            secondaryUint: cTokenIdPut400,
            data: ""
        });

        // have the controller execute the ClaimCollateral action
        controller.operate(actions);

        // check balances
        assertEq(BUSD.balanceOf(user), claimableCollateral);
        assertEq(BUSD.balanceOf(address(controller)), collateralAmount - claimableCollateral);

        assertEq(qTokenPut400.balanceOf(user), optionsAmount);
        assertEq(collateralToken.balanceOf(user, cTokenIdPut400), 0);

        vm.stopPrank();
    }

    function testNeutralizePositionAction() public {
        vm.startPrank(user);

        uint256 optionsAmount = 3 ether;
        uint256 amountToNeutralize = optionsAmount;
        uint256 collateralAmount = optionsAmount;

        // mint the option to the user
        deal(address(WETH), user, collateralAmount, true);
        WETH.approve(address(controller), type(uint256).max);
        controller.mintOptionsPosition(user, address(qTokenCall3520), optionsAmount);

        // get an array with the action to neutralize the user's position
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({
            actionType: ActionType.Neutralize,
            qToken: address(0),
            secondaryAddress: address(0),
            receiver: address(0),
            amount: amountToNeutralize,
            secondaryUint: cTokenIdCall3520,
            data: ""
        });

        // have the Controller execute the Neutralize action
        controller.operate(actions);

        // check balances
        assertEq(qTokenCall3520.balanceOf(user), 0);
        assertEq(collateralToken.balanceOf(user, cTokenIdCall3520), 0);

        assertEq(WETH.balanceOf(user), collateralAmount);
        assertEq(WETH.balanceOf(address(controller)), 0);

        vm.stopPrank();
    }

    function testQTokenPermitAction() public {
        vm.startPrank(user);

        uint256 deadline = block.timestamp + 3 days;
        uint256 value = 1 ether;
        QToken qToken = qTokenCall3520;
        address owner = user;
        address spender = secondaryAccount;

        bytes32 permitHashedData = keccak256(
            abi.encodePacked(
                "\x19\x01",
                qToken.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        owner,
                        spender,
                        value,
                        qToken.nonces(owner),
                        deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivKey, permitHashedData);

        bytes memory permitSignature = abi.encode(v, r, s);

        // get an array with the action to call permit on the QToken
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({
            actionType: ActionType.QTokenPermit,
            qToken: address(qToken),
            secondaryAddress: owner,
            receiver: spender,
            amount: value,
            secondaryUint: deadline,
            data: permitSignature
        });

        // have the Controller execute the QTokenPermit action
        controller.operate(actions);

        // check the allowance
        assertEq(qToken.allowance(owner, spender), value);

        vm.stopPrank();
    }

    function testCollateralTokenApprovalAction() public {
        vm.startPrank(user);

        uint256 deadline = block.timestamp + 42 days;
        address owner = secondaryAccount;
        address operator = user;
        bool approved = true;
        uint256 collateralTokenNonce = collateralToken.nonces(owner);

        bytes32 metaSetApprovalHashedData;

        {
            bytes32 typeHash =
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

            // keccak256(
            //     "metaSetApprovalForAll(address cTokenOwner,address operator,bool approved,uint256 nonce,uint256 deadline)"
            // );
            bytes32 META_APPROVAL_TYPEHASH = 0x8733d126a676f1e83270eccfbe576f65af55d3ff784c4dc4884be48932f47c81;

            bytes32 COLLATERAL_TOKEN_DOMAIN_SEPARATOR = keccak256(
                abi.encode(
                    typeHash,
                    keccak256(bytes("Quant Protocol")),
                    keccak256(bytes("1.0.0")),
                    block.chainid,
                    address(collateralToken)
                )
            );

            metaSetApprovalHashedData = keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    COLLATERAL_TOKEN_DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(META_APPROVAL_TYPEHASH, owner, operator, approved, collateralTokenNonce, deadline)
                    )
                )
            );
        }

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(secondaryAccountPrivKey, metaSetApprovalHashedData);

        bytes memory metaSetApprovalData = abi.encode(approved, v, r, s);

        // get an array with the action to call metaSetApprovalForAll on the CollateralToken
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({
            actionType: ActionType.CollateralTokenApproval,
            qToken: address(0),
            secondaryAddress: owner,
            receiver: operator,
            amount: collateralTokenNonce,
            secondaryUint: deadline,
            data: metaSetApprovalData
        });

        // have the Controller execute the CollateralTokenApproval action
        controller.operate(actions);

        // check the approval
        assertEq(collateralToken.isApprovedForAll(owner, operator), true);

        vm.stopPrank();
    }

    function testCallAction() public {
        vm.startPrank(user);

        uint256 amountToApprove = 4 ether;
        bytes memory approveCallData = abi.encodeCall(WETH.approve, (user, amountToApprove));

        // get an array with the action to call approve on WETH as the OperateProxy
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({
            actionType: ActionType.Call,
            qToken: address(0),
            secondaryAddress: address(0),
            receiver: address(WETH),
            amount: 0,
            secondaryUint: 0,
            data: approveCallData
        });

        // have the Controller execute the Call action
        controller.operate(actions);

        // check that the call was actually executed
        assertEq(WETH.allowance(address(controller.operateProxy()), user), amountToApprove);

        vm.stopPrank();
    }

    function testCannotCallPermitOnNonQToken() public {
        vm.startPrank(user);

        uint256 deadline = block.timestamp + 7 days;
        uint256 value = 1 ether;
        address notAQToken = address(90210);
        address owner = user;
        address spender = secondaryAccount;

        bytes32 permitHashedData = keccak256(
            abi.encodePacked(
                "\x19\x01",
                qTokenCall3520.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        owner,
                        spender,
                        value,
                        qTokenCall3520.nonces(owner),
                        deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivKey, permitHashedData);

        bytes memory permitSignature = abi.encode(v, r, s);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({
            actionType: ActionType.QTokenPermit,
            qToken: notAQToken,
            secondaryAddress: owner,
            receiver: spender,
            amount: value,
            secondaryUint: deadline,
            data: permitSignature
        });

        vm.expectRevert(bytes("Controller: not a QToken for calling permit"));
        controller.operate(actions);

        vm.stopPrank();
    }
}
