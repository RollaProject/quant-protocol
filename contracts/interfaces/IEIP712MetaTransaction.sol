// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

interface IEIP712MetaTransaction {
    function executeMetaTransaction(
        address,
        bytes memory,
        bytes32,
        bytes32,
        uint8
    ) external payable returns (bytes memory);

    function getNonce(address) external view returns (uint256);
}
