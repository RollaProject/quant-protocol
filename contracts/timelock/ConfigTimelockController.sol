// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./TimelockController.sol";
import "../interfaces/IQuantConfig.sol";

contract ConfigTimelockController is TimelockController {
    using SafeMath for uint256;

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

        super.schedule(target, value, data, predecessor, salt, delay);
    }

    function scheduleSetProtocolAddress(
        bytes32 protocolAddress,
        address newAddress,
        address quantConfig,
        uint256 eta
    ) public onlyRole(PROPOSER_ROLE) {
        bytes memory data =
            _encodeSetProtocolAddress(protocolAddress, newAddress, quantConfig);

        uint256 delay = _getProtocolValueDelay(protocolAddress);

        require(
            eta >= delay.add(block.timestamp),
            "ConfigTimelockController: Estimated execution block must satisfy delay"
        );

        super.schedule(quantConfig, 0, data, bytes32(0), bytes32(eta), delay);
    }

    function scheduleSetProtocolUint256(
        bytes32 protocolUint256,
        uint256 newUint256,
        address quantConfig,
        uint256 eta
    ) public onlyRole(PROPOSER_ROLE) {
        bytes memory data =
            _encodeSetProtocolUint256(protocolUint256, newUint256, quantConfig);

        uint256 delay = _getProtocolValueDelay(protocolUint256);

        require(
            eta >= delay.add(block.timestamp),
            "ConfigTimelockController: Estimated execution block must satisfy delay"
        );

        super.schedule(quantConfig, 0, data, bytes32(0), bytes32(eta), delay);
    }

    function scheduleSetProtocolBoolean(
        bytes32 protocolBoolean,
        bool newBoolean,
        address quantConfig,
        uint256 eta
    ) public onlyRole(PROPOSER_ROLE) {
        bytes memory data =
            _encodeSetProtocolBoolean(protocolBoolean, newBoolean, quantConfig);

        uint256 delay = _getProtocolValueDelay(protocolBoolean);

        require(
            eta >= delay.add(block.timestamp),
            "ConfigTimelockController: Estimated execution block must satisfy delay"
        );
        super.schedule(quantConfig, 0, data, bytes32(0), bytes32(eta), delay);
    }

    function scheduleSetProtocolRole(
        string calldata protocolRole,
        address roleAdmin,
        address quantConfig,
        uint256 eta
    ) public onlyRole(PROPOSER_ROLE) {
        bytes memory data =
            _encodeSetProtocolRole(protocolRole, roleAdmin, quantConfig);

        uint256 delay =
            _getProtocolValueDelay(keccak256(abi.encodePacked(protocolRole)));

        require(
            eta >= delay.add(block.timestamp),
            "ConfigTimelockController: Estimated execution block must satisfy delay"
        );

        super.schedule(quantConfig, 0, data, bytes32(0), bytes32(eta), delay);
    }

    function scheduleBatch(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory datas,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) public virtual override onlyRole(PROPOSER_ROLE) {
        for (uint256 i = 0; i < targets.length; ++i) {
            require(
                !_isProtocoValueSetter(datas[i]),
                "ConfigTimelockController: Can not schedule changes to a protocol value with an arbitrary delay"
            );
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

        for (uint256 i = 0; i < length; i++) {
            scheduleSetProtocolAddress(
                protocolValues[i],
                newAddresses[i],
                quantConfig,
                eta
            );
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

        for (uint256 i = 0; i < length; i++) {
            scheduleSetProtocolUint256(
                protocolValues[i],
                newUints[i],
                quantConfig,
                eta
            );
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

        for (uint256 i = 0; i < length; i++) {
            scheduleSetProtocolBoolean(
                protocolValues[i],
                newBooleans[i],
                quantConfig,
                eta
            );
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

        for (uint256 i = 0; i < length; i++) {
            scheduleSetProtocolRole(
                protocolRoles[i],
                roleAdmins[i],
                quantConfig,
                eta
            );
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

        for (uint256 i = 0; i < length; i++) {
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

        for (uint256 i = 0; i < length; i++) {
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

        for (uint256 i = 0; i < length; i++) {
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

        for (uint256 i = 0; i < length; i++) {
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
        }
    }

    function _getProtocolValueDelay(bytes32 protocolValue)
        internal
        view
        returns (uint256)
    {
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
