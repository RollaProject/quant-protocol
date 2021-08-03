// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.0;
pragma abicoder v2;

import "../libraries/Actions.sol";

contract ActionsTester {
    function testParseMintOptionArgs(ActionArgs memory args)
        external
        pure
        returns (Actions.MintOptionArgs memory)
    {
        return Actions.parseMintOptionArgs(args);
    }

    function testParseMintSpreadArgs(ActionArgs memory args)
        external
        pure
        returns (Actions.MintSpreadArgs memory)
    {
        return Actions.parseMintSpreadArgs(args);
    }

    function testParseExerciseArgs(ActionArgs memory args)
        external
        pure
        returns (Actions.ExerciseArgs memory)
    {
        return Actions.parseExerciseArgs(args);
    }

    function testParseClaimCollateralArgs(ActionArgs memory args)
        external
        pure
        returns (Actions.ClaimCollateralArgs memory)
    {
        return Actions.parseClaimCollateralArgs(args);
    }

    function testParseNeutralizeArgs(ActionArgs memory args)
        external
        pure
        returns (Actions.NeutralizeArgs memory)
    {
        return Actions.parseNeutralizeArgs(args);
    }

    function testParseQTokenPermitArgs(ActionArgs memory args)
        external
        pure
        returns (Actions.QTokenPermitArgs memory)
    {
        return Actions.parseQTokenPermitArgs(args);
    }

    function testParseCollateralTokenApprovalArgs(ActionArgs memory args)
        external
        pure
        returns (Actions.CollateralTokenApprovalArgs memory)
    {
        return Actions.parseCollateralTokenApprovalArgs(args);
    }

    function testParseCallArgs(ActionArgs memory args)
        external
        pure
        returns (Actions.CallArgs memory)
    {
        return Actions.parseCallArgs(args);
    }
}
