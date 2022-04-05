// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IEIP712MetaTransaction {
    function executeMetaTransaction(
        address,
        bytes memory,
        uint256,
        bytes32,
        bytes32,
        uint8
    ) external payable returns (bytes memory);

    function getNonce(address) external view returns (uint256);
}
