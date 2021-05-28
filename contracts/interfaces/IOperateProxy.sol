// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

interface IOperateProxy {
    event FunctionCallExecuted(
        address indexed originalSender,
        bytes returnData
    );

    function callFunction(address, bytes memory) external;
}
