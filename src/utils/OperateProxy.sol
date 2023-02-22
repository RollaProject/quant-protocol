// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import "@openzeppelin/contracts/utils/Address.sol";
import "../interfaces/IOperateProxy.sol";

/// @title Contract to be used by the Controller to make unprivileged external calls
/// @author Rolla
contract OperateProxy is IOperateProxy {
    using Address for address;

    /// @inheritdoc IOperateProxy
    function callFunction(address callee, bytes memory data) external override {
        require(callee.isContract(), "OperateProxy: callee is not a contract");

        (bool success, bytes memory returnData) = address(callee).call(data);
        require(success, "OperateProxy: low-level call failed");
        emit FunctionCallExecuted(tx.origin, returnData);
    }
}
