// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.12;

import "./TimelockController.sol";
import "../interfaces/IQuantConfig.sol";
import "../libraries/ProtocolValue.sol";

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
        uint256 delay,
        bool
    ) public virtual override onlyRole(PROPOSER_ROLE) {
        require(
            !_isProtocoValueSetter(data),
            "ConfigTimelockController: Can not schedule changes to a protocol value with an arbitrary delay"
        );

        super.schedule(target, value, data, predecessor, salt, delay, false);
    }

    function scheduleSetProtocolAddress(
        bytes32 protocolAddress,
        address newAddress,
        address quantConfig,
        uint256 eta
    ) public onlyRole(PROPOSER_ROLE) {
        bytes memory data = _encodeSetProtocolAddress(
            protocolAddress,
            newAddress,
            quantConfig
        );

        uint256 delay = _getProtocolValueDelay(
            quantConfig,
            protocolAddress,
            ProtocolValue.Type.Address
        );

        require(
            eta >= delay + block.timestamp,
            "ConfigTimelockController: Estimated execution block must satisfy delay"
        );

        super.schedule(
            quantConfig,
            0,
            data,
            bytes32(0),
            bytes32(eta),
            delay,
            true
        );
    }

    function scheduleSetProtocolUint256(
        bytes32 protocolUint256,
        uint256 newUint256,
        address quantConfig,
        uint256 eta
    ) public onlyRole(PROPOSER_ROLE) {
        bytes memory data = _encodeSetProtocolUint256(
            protocolUint256,
            newUint256,
            quantConfig
        );

        uint256 delay = _getProtocolValueDelay(
            quantConfig,
            protocolUint256,
            ProtocolValue.Type.Uint256
        );

        require(
            eta >= delay + block.timestamp,
            "ConfigTimelockController: Estimated execution block must satisfy delay"
        );

        super.schedule(
            quantConfig,
            0,
            data,
            bytes32(0),
            bytes32(eta),
            delay,
            true
        );
    }

    function scheduleSetProtocolBoolean(
        bytes32 protocolBoolean,
        bool newBoolean,
        address quantConfig,
        uint256 eta
    ) public onlyRole(PROPOSER_ROLE) {
        bytes memory data = _encodeSetProtocolBoolean(
            protocolBoolean,
            newBoolean,
            quantConfig
        );

        uint256 delay = _getProtocolValueDelay(
            quantConfig,
            protocolBoolean,
            ProtocolValue.Type.Bool
        );

        require(
            eta >= delay + block.timestamp,
            "ConfigTimelockController: Estimated execution block must satisfy delay"
        );
        super.schedule(
            quantConfig,
            0,
            data,
            bytes32(0),
            bytes32(eta),
            delay,
            true
        );
    }

    function scheduleSetProtocolRole(
        string calldata protocolRole,
        address roleAdmin,
        address quantConfig,
        uint256 eta
    ) public onlyRole(PROPOSER_ROLE) {
        bytes memory data = _encodeSetProtocolRole(
            protocolRole,
            roleAdmin,
            quantConfig
        );

        uint256 delay = _getProtocolValueDelay(
            quantConfig,
            keccak256(abi.encodePacked(protocolRole)),
            ProtocolValue.Type.Role
        );

        require(
            eta >= delay + block.timestamp,
            "ConfigTimelockController: Estimated execution block must satisfy delay"
        );

        super.schedule(
            quantConfig,
            0,
            data,
            bytes32(0),
            bytes32(eta),
            delay,
            true
        );
    }

    function scheduleBatch(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory datas,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) public virtual override onlyRole(PROPOSER_ROLE) {
        uint256 length = targets.length;
        for (uint256 i = 0; i < length; ) {
            require(
                !_isProtocoValueSetter(datas[i]),
                "ConfigTimelockController: Can not schedule changes to a protocol value with an arbitrary delay"
            );
            unchecked {
                i++;
            }
        }

        super.scheduleBatch(targets, values, datas, predecessor, salt, delay);
    }

    function scheduleBatchSetProtocolAddress(
        bytes32[] calldata protocolValues,
        address[] calldata newAddresses,
        address quantConfig,
        uint256 eta
    ) public onlyRole(PROPOSER_ROLE) {
        uint256 length = protocolValues.length;

        require(
            length == newAddresses.length,
            "ConfigTimelockController: length mismatch"
        );

        for (uint256 i = 0; i < length; ) {
            scheduleSetProtocolAddress(
                protocolValues[i],
                newAddresses[i],
                quantConfig,
                eta
            );
            unchecked {
                i++;
            }
        }
    }

    function scheduleBatchSetProtocolUints(
        bytes32[] calldata protocolValues,
        uint256[] calldata newUints,
        address quantConfig,
        uint256 eta
    ) public onlyRole(PROPOSER_ROLE) {
        uint256 length = protocolValues.length;

        require(
            length == newUints.length,
            "ConfigTimelockController: length mismatch"
        );

        for (uint256 i = 0; i < length; ) {
            scheduleSetProtocolUint256(
                protocolValues[i],
                newUints[i],
                quantConfig,
                eta
            );
            unchecked {
                i++;
            }
        }
    }

    function scheduleBatchSetProtocolBooleans(
        bytes32[] calldata protocolValues,
        bool[] calldata newBooleans,
        address quantConfig,
        uint256 eta
    ) public onlyRole(PROPOSER_ROLE) {
        uint256 length = protocolValues.length;

        require(
            length == newBooleans.length,
            "ConfigTimelockController: length mismatch"
        );

        for (uint256 i = 0; i < length; ) {
            scheduleSetProtocolBoolean(
                protocolValues[i],
                newBooleans[i],
                quantConfig,
                eta
            );
            unchecked {
                i++;
            }
        }
    }

    function scheduleBatchSetProtocolRoles(
        string[] calldata protocolRoles,
        address[] calldata roleAdmins,
        address quantConfig,
        uint256 eta
    ) public onlyRole(PROPOSER_ROLE) {
        uint256 length = protocolRoles.length;

        require(
            length == roleAdmins.length,
            "ConfigTimelockController: length mismatch"
        );

        for (uint256 i = 0; i < length; ) {
            scheduleSetProtocolRole(
                protocolRoles[i],
                roleAdmins[i],
                quantConfig,
                eta
            );
            unchecked {
                i++;
            }
        }
    }

    function executeSetProtocolAddress(
        bytes32 protocolAddress,
        address newAddress,
        address quantConfig,
        uint256 eta
    ) public onlyRole(EXECUTOR_ROLE) {
        execute(
            quantConfig,
            0,
            _encodeSetProtocolAddress(protocolAddress, newAddress, quantConfig),
            bytes32(0),
            bytes32(eta)
        );
    }

    function executeSetProtocolUint256(
        bytes32 protocolUint256,
        uint256 newUint256,
        address quantConfig,
        uint256 eta
    ) public onlyRole(EXECUTOR_ROLE) {
        execute(
            quantConfig,
            0,
            _encodeSetProtocolUint256(protocolUint256, newUint256, quantConfig),
            bytes32(0),
            bytes32(eta)
        );
    }

    function executeSetProtocolBoolean(
        bytes32 protocolBoolean,
        bool newBoolean,
        address quantConfig,
        uint256 eta
    ) public onlyRole(EXECUTOR_ROLE) {
        execute(
            quantConfig,
            0,
            _encodeSetProtocolBoolean(protocolBoolean, newBoolean, quantConfig),
            bytes32(0),
            bytes32(eta)
        );
    }

    function executeSetProtocolRole(
        string calldata protocolRole,
        address roleAdmin,
        address quantConfig,
        uint256 eta
    ) public onlyRole(EXECUTOR_ROLE) {
        execute(
            quantConfig,
            0,
            _encodeSetProtocolRole(protocolRole, roleAdmin, quantConfig),
            bytes32(0),
            bytes32(eta)
        );
    }

    function executeBatchSetProtocolAddress(
        bytes32[] calldata protocolValues,
        address[] calldata newAddresses,
        address quantConfig,
        uint256 eta
    ) public onlyRole(EXECUTOR_ROLE) {
        uint256 length = protocolValues.length;

        require(
            length == newAddresses.length,
            "ConfigTimelockController: length mismatch"
        );

        for (uint256 i = 0; i < length; ) {
            execute(
                quantConfig,
                0,
                _encodeSetProtocolAddress(
                    protocolValues[i],
                    newAddresses[i],
                    quantConfig
                ),
                bytes32(0),
                bytes32(eta)
            );
            unchecked {
                i++;
            }
        }
    }

    function executeBatchSetProtocolUint256(
        bytes32[] calldata protocolValues,
        uint256[] calldata newUints,
        address quantConfig,
        uint256 eta
    ) public onlyRole(EXECUTOR_ROLE) {
        uint256 length = protocolValues.length;

        require(
            length == newUints.length,
            "ConfigTimelockController: length mismatch"
        );

        for (uint256 i = 0; i < length; ) {
            execute(
                quantConfig,
                0,
                _encodeSetProtocolUint256(
                    protocolValues[i],
                    newUints[i],
                    quantConfig
                ),
                bytes32(0),
                bytes32(eta)
            );
            unchecked {
                i++;
            }
        }
    }

    function executeBatchSetProtocolBoolean(
        bytes32[] calldata protocolValues,
        bool[] calldata newBooleans,
        address quantConfig,
        uint256 eta
    ) public onlyRole(EXECUTOR_ROLE) {
        uint256 length = protocolValues.length;

        require(
            length == newBooleans.length,
            "ConfigTimelockController: length mismatch"
        );

        for (uint256 i = 0; i < length; ) {
            execute(
                quantConfig,
                0,
                _encodeSetProtocolBoolean(
                    protocolValues[i],
                    newBooleans[i],
                    quantConfig
                ),
                bytes32(0),
                bytes32(eta)
            );
            unchecked {
                i++;
            }
        }
    }

    function executeBatchSetProtocolRoles(
        string[] calldata protocolRoles,
        address[] calldata roleAdmins,
        address quantConfig,
        uint256 eta
    ) public onlyRole(EXECUTOR_ROLE) {
        uint256 length = protocolRoles.length;

        require(
            length == roleAdmins.length,
            "ConfigTimelockController: length mismatch"
        );

        for (uint256 i = 0; i < length; ) {
            execute(
                quantConfig,
                0,
                _encodeSetProtocolRole(
                    protocolRoles[i],
                    roleAdmins[i],
                    quantConfig
                ),
                bytes32(0),
                bytes32(eta)
            );
            unchecked {
                i++;
            }
        }
    }

    function _getProtocolValueDelay(
        address quantConfig,
        bytes32 protocolValue,
        ProtocolValue.Type protocolValueType
    ) internal view returns (uint256) {
        // There shouldn't be a delay when setting a protocol value for the first time
        if (
            !IQuantConfig(quantConfig).isProtocolValueSet(
                protocolValue,
                protocolValueType
            )
        ) {
            return 0;
        }

        uint256 storedDelay = delays[protocolValue];
        return storedDelay != 0 ? storedDelay : minDelay;
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

    function _encodeSetProtocolAddress(
        bytes32 _protocolAddress,
        address _newAddress,
        address _quantConfig
    ) internal pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                IQuantConfig(_quantConfig).setProtocolAddress.selector,
                _protocolAddress,
                _newAddress
            );
    }

    function _encodeSetProtocolUint256(
        bytes32 _protocolUint256,
        uint256 _newUint256,
        address _quantConfig
    ) internal pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                IQuantConfig(_quantConfig).setProtocolUint256.selector,
                _protocolUint256,
                _newUint256
            );
    }

    function _encodeSetProtocolBoolean(
        bytes32 _protocolBoolean,
        bool _newBoolean,
        address _quantConfig
    ) internal pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                IQuantConfig(_quantConfig).setProtocolBoolean.selector,
                _protocolBoolean,
                _newBoolean
            );
    }

    function _encodeSetProtocolRole(
        string memory _protocolRole,
        address _roleAdmin,
        address _quantConfig
    ) internal pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                IQuantConfig(_quantConfig).setProtocolRole.selector,
                _protocolRole,
                _roleAdmin
            );
    }
}
