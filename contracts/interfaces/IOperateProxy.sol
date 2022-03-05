// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IOperateProxy {
    event FunctionCallExecuted(
        address indexed originalSender,
        bytes returnData
    );

    function callFunction(address, bytes memory) external;
}
