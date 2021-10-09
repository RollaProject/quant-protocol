// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;

import "../interfaces/IOperateProxy.sol";

contract OperateProxy is IOperateProxy {
    function callFunction(address callee, bytes memory data) external override {
        (bool success, bytes memory returnData) = address(callee).call(data);
        require(success, "OperateProxy: low-level call failed");
        emit FunctionCallExecuted(tx.origin, returnData);
    }
}
