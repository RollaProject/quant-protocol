// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../libraries/Actions.sol";

contract ActionsTester {
    function parseMintOptionArgsTest(ActionArgs memory args) external pure returns (address, address, uint256) {
        return Actions.parseMintOptionArgs(args);
    }

    function parseMintSpreadArgsTest(ActionArgs memory args) external pure returns (address, address, uint256) {
        return Actions.parseMintSpreadArgs(args);
    }

    function parseExerciseArgsTest(ActionArgs memory args) external pure returns (address, uint256) {
        return Actions.parseExerciseArgs(args);
    }

    function parseClaimCollateralArgsTest(ActionArgs memory args) external pure returns (uint256, uint256) {
        return Actions.parseClaimCollateralArgs(args);
    }

    function parseNeutralizeArgsTest(ActionArgs memory args) external pure returns (uint256, uint256) {
        return Actions.parseNeutralizeArgs(args);
    }

    function parseQTokenPermitArgsTest(ActionArgs memory args)
        external
        pure
        returns (address, address, address, uint256, uint256, uint8, bytes32, bytes32)
    {
        return Actions.parseQTokenPermitArgs(args);
    }

    function parseCollateralTokenApprovalArgsTest(ActionArgs memory args)
        external
        pure
        returns (address, address, bool, uint256, uint256, uint8, bytes32, bytes32)
    {
        return Actions.parseCollateralTokenApprovalArgs(args);
    }

    function parseCallArgsTest(ActionArgs memory args) external pure returns (address, bytes memory) {
        return Actions.parseCallArgs(args);
    }
}
