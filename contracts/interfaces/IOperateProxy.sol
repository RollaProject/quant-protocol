// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IOperateProxy {
    /// @notice emitted when a external contract call is executed
    event FunctionCallExecuted(address indexed originalSender, bytes returnData);

    /// @notice Makes a call to an external contract
    /// WARNING: DO NOT UNDER ANY CIRCUMSTANCES APPROVE THE OperateProxy TO
    /// SPEND YOUR FUNDS (using CALL action) OR ANYONE WILL BE ABLE TO SPEND THEM AFTER YOU!!!
    /// @param callee address of the contract to call
    /// @param data the calldata to send to the contract
    function callFunction(address callee, bytes memory data) external;
}