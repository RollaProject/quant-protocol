// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../src/libraries/Actions.sol";
import "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract TestParseMintOptionArgs is Test {
    function testCannotPassZeroAmount() public {
        vm.expectRevert("Actions: cannot mint 0 options");
        Actions.parseMintOptionArgs(
            ActionArgs({
                actionType: ActionType.MintOption,
                qToken: address(0),
                secondaryAddress: address(0),
                receiver: address(0),
                amount: 0,
                secondaryUint: 0,
                data: ""
            })
        );
    }

    function testParseValidParameters() public {
        address qToken = address(12);
        address receiver = address(34);
        uint256 amount = 56;

        (address parsedReceiver, address parsedQToken, uint256 parsedAmount) = Actions.parseMintOptionArgs(
            ActionArgs({
                actionType: ActionType.MintOption,
                qToken: qToken,
                secondaryAddress: address(0),
                receiver: receiver,
                amount: amount,
                secondaryUint: 0,
                data: ""
            })
        );

        assertEq(qToken, parsedQToken);
        assertEq(receiver, parsedReceiver);
        assertEq(amount, parsedAmount);
    }

    function testCannotPassZeroAmount(
        address qToken,
        address secondaryAddress,
        address receiver,
        uint256 secondaryUint,
        bytes memory data
    ) public {
        vm.expectRevert("Actions: cannot mint 0 options");
        Actions.parseMintOptionArgs(
            ActionArgs({
                actionType: ActionType.MintOption,
                qToken: qToken,
                secondaryAddress: secondaryAddress,
                receiver: receiver,
                amount: 0,
                secondaryUint: secondaryUint,
                data: data
            })
        );
    }

    function testParseValidParameters(
        address qToken,
        address secondaryAddress,
        address receiver,
        uint256 amount,
        uint256 secondaryUint,
        bytes memory data
    ) public {
        vm.assume(amount != 0);

        (address parsedReceiver, address parsedQToken, uint256 parsedAmount) = Actions.parseMintOptionArgs(
            ActionArgs({
                actionType: ActionType.MintOption,
                qToken: qToken,
                secondaryAddress: secondaryAddress,
                receiver: receiver,
                amount: amount,
                secondaryUint: secondaryUint,
                data: data
            })
        );

        assertEq(qToken, parsedQToken);
        assertEq(receiver, parsedReceiver);
        assertEq(amount, parsedAmount);
    }
}

contract TestParseMintSpreadArgs is Test {
    function testCannotPassZeroAmount() public {
        vm.expectRevert("Actions: cannot mint 0 options from spreads");
        Actions.parseMintSpreadArgs(
            ActionArgs({
                actionType: ActionType.MintSpread,
                qToken: address(0),
                secondaryAddress: address(0),
                receiver: address(0),
                amount: 0,
                secondaryUint: 0,
                data: ""
            })
        );
    }

    function testParseValidParameters() public {
        address qTokenToMint = address(222);
        address qTokenForCollateral = address(444);
        uint256 amount = 666;

        (address parsedQTokenToMint, address parsedQTokenForCollateral, uint256 parsedAmount) = Actions
            .parseMintSpreadArgs(
            ActionArgs({
                actionType: ActionType.MintSpread,
                qToken: qTokenToMint,
                secondaryAddress: qTokenForCollateral,
                receiver: address(0),
                amount: amount,
                secondaryUint: 0,
                data: ""
            })
        );

        assertEq(qTokenToMint, parsedQTokenToMint);
        assertEq(qTokenForCollateral, parsedQTokenForCollateral);
        assertEq(amount, parsedAmount);
    }

    function testCannotPassZeroAmount(
        address qToken,
        address secondaryAddress,
        address receiver,
        uint256 secondaryUint,
        bytes memory data
    ) public {
        vm.expectRevert("Actions: cannot mint 0 options from spreads");
        Actions.parseMintSpreadArgs(
            ActionArgs({
                actionType: ActionType.MintSpread,
                qToken: qToken,
                secondaryAddress: secondaryAddress,
                receiver: receiver,
                amount: 0,
                secondaryUint: secondaryUint,
                data: data
            })
        );
    }

    function testParseValidParameters(
        address qTokenToMint,
        address qTokenForCollateral,
        address receiver,
        uint256 amount,
        uint256 secondaryUint,
        bytes memory data
    ) public {
        vm.assume(amount != 0);

        (address parsedQTokenToMint, address parsedQTokenForCollateral, uint256 parsedAmount) = Actions
            .parseMintSpreadArgs(
            ActionArgs({
                actionType: ActionType.MintSpread,
                qToken: qTokenToMint,
                secondaryAddress: qTokenForCollateral,
                receiver: receiver,
                amount: amount,
                secondaryUint: secondaryUint,
                data: data
            })
        );

        assertEq(qTokenToMint, parsedQTokenToMint);
        assertEq(qTokenForCollateral, parsedQTokenForCollateral);
        assertEq(amount, parsedAmount);
    }
}

contract TestParseExerciseArgs is Test {
    function testParseValidParameters() public {
        address qToken = address(1738);
        uint256 amount = 2 ether;

        (address parsedQToken, uint256 parsedAmount) = Actions.parseExerciseArgs(
            ActionArgs({
                actionType: ActionType.Exercise,
                qToken: qToken,
                secondaryAddress: address(0),
                receiver: address(0),
                amount: amount,
                secondaryUint: 0,
                data: ""
            })
        );

        assertEq(qToken, parsedQToken);
        assertEq(amount, parsedAmount);
    }

    function testParseValidParameters(
        address qToken,
        address secondaryAddress,
        address receiver,
        uint256 amount,
        uint256 secondaryUint,
        bytes memory data
    ) public {
        (address parsedQToken, uint256 parsedAmount) = Actions.parseExerciseArgs(
            ActionArgs({
                actionType: ActionType.Exercise,
                qToken: qToken,
                secondaryAddress: secondaryAddress,
                receiver: receiver,
                amount: amount,
                secondaryUint: secondaryUint,
                data: data
            })
        );

        assertEq(qToken, parsedQToken);
        assertEq(amount, parsedAmount);
    }
}

contract TestParseClaimCollateralArgs is Test {
    function testParseValidParameters() public {
        uint256 collateralTokenId = 1;
        uint256 amount = 2;

        (uint256 parsedCollateralTokenId, uint256 parsedAmount) = Actions.parseClaimCollateralArgs(
            ActionArgs({
                actionType: ActionType.ClaimCollateral,
                qToken: address(0),
                secondaryAddress: address(0),
                receiver: address(0),
                amount: amount,
                secondaryUint: collateralTokenId,
                data: ""
            })
        );

        assertEq(collateralTokenId, parsedCollateralTokenId);
        assertEq(amount, parsedAmount);
    }

    function testParseValidParameters(
        address qToken,
        address secondaryAddress,
        address receiver,
        uint256 amount,
        uint256 collateralTokenId,
        bytes memory data
    ) public {
        (uint256 parsedCollateralTokenId, uint256 parsedAmount) = Actions.parseClaimCollateralArgs(
            ActionArgs({
                actionType: ActionType.ClaimCollateral,
                qToken: qToken,
                secondaryAddress: secondaryAddress,
                receiver: receiver,
                amount: amount,
                secondaryUint: collateralTokenId,
                data: data
            })
        );

        assertEq(collateralTokenId, parsedCollateralTokenId);
        assertEq(amount, parsedAmount);
    }
}

contract TestParseNeutralizeArgs is Test {
    function testParseValidParameters() public {
        uint256 collateralTokenId = 123;
        uint256 amount = 456;

        (uint256 parsedCollateralTokenId, uint256 parsedAmount) = Actions.parseNeutralizeArgs(
            ActionArgs({
                actionType: ActionType.Neutralize,
                qToken: address(0),
                secondaryAddress: address(0),
                receiver: address(0),
                amount: amount,
                secondaryUint: collateralTokenId,
                data: ""
            })
        );

        assertEq(collateralTokenId, parsedCollateralTokenId);
        assertEq(amount, parsedAmount);
    }

    function testParseValidParameters(
        address qToken,
        address secondaryAddress,
        address receiver,
        uint256 amount,
        uint256 collateralTokenId,
        bytes memory data
    ) public {
        (uint256 parsedCollateralTokenId, uint256 parsedAmount) = Actions.parseNeutralizeArgs(
            ActionArgs({
                actionType: ActionType.Neutralize,
                qToken: qToken,
                secondaryAddress: secondaryAddress,
                receiver: receiver,
                amount: amount,
                secondaryUint: collateralTokenId,
                data: data
            })
        );

        assertEq(collateralTokenId, parsedCollateralTokenId);
        assertEq(amount, parsedAmount);
    }
}

contract TestParseQTokenPermitArgs is Test {
    struct QTokenPermitArgs {
        address qToken;
        address owner;
        address spender;
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function testParseValidParameters() public {
        address qToken = address(1600800);
        address owner = address(1111);
        address spender = address(2222);
        uint256 value = type(uint256).max;
        uint256 deadline = block.timestamp + 1 days;
        uint8 v = 27;
        bytes32 r = keccak256("some r value");
        bytes32 s = keccak256("some s value");
        bytes memory data = abi.encode(v, r, s);

        QTokenPermitArgs memory parsedArgs;

        (
            parsedArgs.qToken,
            parsedArgs.owner,
            parsedArgs.spender,
            parsedArgs.value,
            parsedArgs.deadline,
            parsedArgs.v,
            parsedArgs.r,
            parsedArgs.s
        ) = Actions.parseQTokenPermitArgs(
            ActionArgs({
                actionType: ActionType.QTokenPermit,
                qToken: qToken,
                secondaryAddress: owner,
                receiver: spender,
                amount: value,
                secondaryUint: deadline,
                data: data
            })
        );

        assertEq(qToken, parsedArgs.qToken);
        assertEq(owner, parsedArgs.owner);
        assertEq(spender, parsedArgs.spender);
        assertEq(value, parsedArgs.value);
        assertEq(deadline, parsedArgs.deadline);
        assertEq(v, parsedArgs.v);
        assertEq(r, parsedArgs.r);
        assertEq(s, parsedArgs.s);
    }

    function testParseValidParameters(
        address qToken,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        bytes memory data = abi.encode(v, r, s);

        QTokenPermitArgs memory parsedArgs;

        (
            parsedArgs.qToken,
            parsedArgs.owner,
            parsedArgs.spender,
            parsedArgs.value,
            parsedArgs.deadline,
            parsedArgs.v,
            parsedArgs.r,
            parsedArgs.s
        ) = Actions.parseQTokenPermitArgs(
            ActionArgs({
                actionType: ActionType.QTokenPermit,
                qToken: qToken,
                secondaryAddress: owner,
                receiver: spender,
                amount: value,
                secondaryUint: deadline,
                data: data
            })
        );

        assertEq(qToken, parsedArgs.qToken);
        assertEq(owner, parsedArgs.owner);
        assertEq(spender, parsedArgs.spender);
        assertEq(value, parsedArgs.value);
        assertEq(deadline, parsedArgs.deadline);
        assertEq(v, parsedArgs.v);
        assertEq(r, parsedArgs.r);
        assertEq(s, parsedArgs.s);
    }
}

contract TestParseCollateralTokenApprovalArgs is Test {
    struct CollateralTokenApprovalArgs {
        address owner;
        address operator;
        bool approved;
        uint256 nonce;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function testParseValidParameters() public {
        address qToken = address(1738);
        address owner = address(999);
        address operator = address(4242);
        bool approved = true;
        uint256 nonce = 72;
        uint256 deadline = block.timestamp + 2 hours;
        uint8 v = 28;
        bytes32 r = keccak256(bytes("some other valid r"));
        bytes32 s = keccak256(bytes("some other valid s"));
        bytes memory data = abi.encode(approved, v, r, s);

        CollateralTokenApprovalArgs memory parsedArgs;

        (
            parsedArgs.owner,
            parsedArgs.operator,
            parsedArgs.approved,
            parsedArgs.nonce,
            parsedArgs.deadline,
            parsedArgs.v,
            parsedArgs.r,
            parsedArgs.s
        ) = Actions.parseCollateralTokenApprovalArgs(
            ActionArgs({
                actionType: ActionType.CollateralTokenApproval,
                qToken: qToken,
                secondaryAddress: owner,
                receiver: operator,
                amount: nonce,
                secondaryUint: deadline,
                data: data
            })
        );

        assertEq(owner, parsedArgs.owner);
        assertEq(operator, parsedArgs.operator);
        assertEq(approved, parsedArgs.approved);
        assertEq(nonce, parsedArgs.nonce);
        assertEq(deadline, parsedArgs.deadline);
        assertEq(v, parsedArgs.v);
        assertEq(r, parsedArgs.r);
        assertEq(s, parsedArgs.s);
    }

    function testParseValidParameters(
        address qToken,
        address owner,
        address operator,
        bool approved,
        uint256 nonce,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        bytes memory data = abi.encode(approved, v, r, s);

        CollateralTokenApprovalArgs memory parsedArgs;

        (
            parsedArgs.owner,
            parsedArgs.operator,
            parsedArgs.approved,
            parsedArgs.nonce,
            parsedArgs.deadline,
            parsedArgs.v,
            parsedArgs.r,
            parsedArgs.s
        ) = Actions.parseCollateralTokenApprovalArgs(
            ActionArgs({
                actionType: ActionType.CollateralTokenApproval,
                qToken: qToken,
                secondaryAddress: owner,
                receiver: operator,
                amount: nonce,
                secondaryUint: deadline,
                data: data
            })
        );

        assertEq(owner, parsedArgs.owner);
        assertEq(operator, parsedArgs.operator);
        assertEq(approved, parsedArgs.approved);
        assertEq(nonce, parsedArgs.nonce);
        assertEq(deadline, parsedArgs.deadline);
        assertEq(v, parsedArgs.v);
        assertEq(r, parsedArgs.r);
        assertEq(s, parsedArgs.s);
    }
}

contract TestParseCallArgs is Test {
    function testParseValidParameters() public {
        address qToken = address(90210);
        address secondaryAddress = address(2222);
        address callee = address(1738);
        uint256 amount = 1 ether;
        uint256 secondaryUint = 2;
        bytes memory data = abi.encodeCall(IERC20.transfer, (callee, amount));

        address parsedCallee;
        bytes memory parsedData;

        (parsedCallee, parsedData) = Actions.parseCallArgs(
            ActionArgs({
                actionType: ActionType.Call,
                qToken: qToken,
                secondaryAddress: secondaryAddress,
                receiver: callee,
                amount: amount,
                secondaryUint: secondaryUint,
                data: data
            })
        );

        assertEq(callee, parsedCallee);
        assertEq(data, parsedData);
    }

    function testParseValidParameters(
        address qToken,
        address secondaryAddress,
        address callee,
        uint256 amount,
        uint256 secondaryUint,
        bytes memory data
    ) public {
        address parsedCallee;
        bytes memory parsedData;

        (parsedCallee, parsedData) = Actions.parseCallArgs(
            ActionArgs({
                actionType: ActionType.Call,
                qToken: qToken,
                secondaryAddress: secondaryAddress,
                receiver: callee,
                amount: amount,
                secondaryUint: secondaryUint,
                data: data
            })
        );

        assertEq(callee, parsedCallee);
        assertEq(data, parsedData);
    }
}
