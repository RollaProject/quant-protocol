// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma abicoder v2;

import "@openzeppelin/contracts/access/TimelockController.sol";
import "./interfaces/IQuantConfig.sol";

contract ConfigTimelockController is TimelockController {
    mapping(bytes32 => uint256) public delays;

    mapping(bytes32 => uint256) private _timestamps;
    uint256 public minDelay;

    constructor(
        uint256 _minDelay,
        address[] memory _proposers,
        address[] memory _executors
    )
        TimelockController(_minDelay, _proposers, _executors)
    // solhint-disable-next-line no-empty-blocks
    {
        minDelay = _minDelay;
    }

    function setDelay(bytes32 _protocolValue, uint256 _newDelay)
        external
        onlyRole(EXECUTOR_ROLE)
    {
        // Delays must be greater than or equal to the minimum delay
        delays[_protocolValue] = _newDelay >= minDelay ? _newDelay : minDelay;
    }

    function schedule(
        address target,
        uint256 value,
        bytes memory data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) public virtual override onlyRole(PROPOSER_ROLE) {
        require(
            !_isProtocoValueSetter(data),
            "ConfigTimelockController: Can not schedule changes to a protocol value with an arbitrary delay"
        );

        bytes32 id = hashOperation(target, value, data, predecessor, salt);
        _scheduleWithDelay(id, delay);
        emit CallScheduled(id, 0, target, value, data, predecessor, delay);
    }

    function scheduleSetProtocolAddress(
        bytes32 protocolAddress,
        address newAddress,
        address quantConfig
    ) public onlyRole(PROPOSER_ROLE) {
        bytes memory data =
            abi.encodeWithSelector(
                IQuantConfig(quantConfig).setProtocolAddress.selector,
                protocolAddress,
                newAddress
            );

        bytes32 id =
            hashOperation(
                quantConfig,
                0,
                data,
                bytes32(0),
                bytes32(block.timestamp)
            );

        uint256 delay = _getProtocolValueDelay(protocolAddress);

        _scheduleWithDelay(id, delay);

        emit CallScheduled(id, 0, quantConfig, 0, data, bytes32(0), delay);
    }

    function scheduleSetProtocolUint256(
        bytes32 protocolUint256,
        uint256 newUint256,
        address quantConfig
    ) public onlyRole(PROPOSER_ROLE) {
        bytes memory data =
            abi.encodeWithSelector(
                IQuantConfig(quantConfig).setProtocolUint256.selector,
                protocolUint256,
                newUint256
            );

        bytes32 id =
            hashOperation(
                quantConfig,
                0,
                data,
                bytes32(0),
                bytes32(block.timestamp)
            );

        uint256 delay = _getProtocolValueDelay(protocolUint256);

        _scheduleWithDelay(id, delay);

        emit CallScheduled(id, 0, quantConfig, 0, data, bytes32(0), delay);
    }

    function scheduleSetProtocolBoolean(
        bytes32 protocolBoolean,
        bool newBoolean,
        address quantConfig
    ) public onlyRole(PROPOSER_ROLE) {
        bytes memory data =
            abi.encodeWithSelector(
                IQuantConfig(quantConfig).setProtocolBoolean.selector,
                protocolBoolean,
                newBoolean
            );

        bytes32 id =
            hashOperation(
                quantConfig,
                0,
                data,
                bytes32(0),
                bytes32(block.timestamp)
            );

        uint256 delay = _getProtocolValueDelay(protocolBoolean);

        _scheduleWithDelay(id, delay);

        emit CallScheduled(id, 0, quantConfig, 0, data, bytes32(0), delay);
    }

    function scheduleBatch(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory datas,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) public virtual override onlyRole(PROPOSER_ROLE) {
        require(
            targets.length == values.length,
            "TimelockController: length mismatch"
        );
        require(
            targets.length == datas.length,
            "TimelockController: length mismatch"
        );

        bytes32 id =
            hashOperationBatch(targets, values, datas, predecessor, salt);
        _scheduleWithDelay(id, delay);
        for (uint256 i = 0; i < targets.length; ++i) {
            require(
                !_isProtocoValueSetter(datas[i]),
                "ConfigTimelockController: Can not schedule changes to a protocol value with an arbitrary delay"
            );
            emit CallScheduled(
                id,
                i,
                targets[i],
                values[i],
                datas[i],
                predecessor,
                delay
            );
        }
    }

    function scheduleBatchSetProtocolAddress(
        bytes32[] calldata protocolValues,
        address[] calldata newAddresses,
        address quantConfig
    ) public onlyRole(PROPOSER_ROLE) {
        require(
            protocolValues.length == newAddresses.length,
            "ConfigTimelockController: length mismatch"
        );

        uint256 length = protocolValues.length;

        for (uint256 i = 0; i < length; i++) {
            scheduleSetProtocolAddress(
                protocolValues[i],
                newAddresses[i],
                quantConfig
            );
        }
    }

    function scheduleBatchSetProtocolUints(
        bytes32[] calldata protocolValues,
        uint256[] calldata newUints,
        address quantConfig
    ) public onlyRole(PROPOSER_ROLE) {
        require(
            protocolValues.length == newUints.length,
            "ConfigTimelockController: length mismatch"
        );

        uint256 length = protocolValues.length;

        for (uint256 i = 0; i < length; i++) {
            scheduleSetProtocolUint256(
                protocolValues[i],
                newUints[i],
                quantConfig
            );
        }
    }

    function scheduleBatchSetProtocolBooleans(
        bytes32[] calldata protocolValues,
        bool[] calldata newBooleans,
        address quantConfig
    ) public onlyRole(PROPOSER_ROLE) {
        require(
            protocolValues.length == newBooleans.length,
            "ConfigTimelockController: length mismatch"
        );

        uint256 length = protocolValues.length;

        for (uint256 i = 0; i < length; i++) {
            scheduleSetProtocolBoolean(
                protocolValues[i],
                newBooleans[i],
                quantConfig
            );
        }
    }

    function hashOperation(
        address target,
        uint256 value,
        bytes memory data,
        bytes32 predecessor,
        bytes32 salt
    ) public pure virtual override returns (bytes32 hash) {
        return keccak256(abi.encode(target, value, data, predecessor, salt));
    }

    function hashOperationBatch(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory datas,
        bytes32 predecessor,
        bytes32 salt
    ) public pure virtual override returns (bytes32 hash) {
        return keccak256(abi.encode(targets, values, datas, predecessor, salt));
    }

    function _isProtocoValueSetter(bytes memory data)
        internal
        pure
        returns (bool)
    {
        bytes4 selector;

        assembly {
            selector := mload(add(data, 32))
        }

        return
            selector == IQuantConfig(address(0)).setProtocolAddress.selector ||
            selector == IQuantConfig(address(0)).setProtocolUint256.selector ||
            selector == IQuantConfig(address(0)).setProtocolBoolean.selector;
    }

    function _getProtocolValueDelay(bytes32 protocolValue)
        internal
        view
        returns (uint256)
    {
        uint256 storedDelay = delays[protocolValue];
        return storedDelay != 0 ? storedDelay : minDelay;
    }

    /**
     * @dev Schedule an operation that is to becomes valid after a given delay.
     */
    function _scheduleWithDelay(bytes32 id, uint256 delay) private {
        require(
            !isOperation(id),
            "TimelockController: operation already scheduled"
        );
        require(
            delay >= getMinDelay(),
            "TimelockController: insufficient delay"
        );
        _timestamps[id] = SafeMath.add(block.timestamp, delay);
    }
}
