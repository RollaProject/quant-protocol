// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./libraries/ProtocolValue.sol";
import "./interfaces/ITimelockedConfig.sol";

/// @title A central config for the quant system. Also acts as a central access control manager.
/// @notice For storing constants, variables and allowing them to be changed by the admin (governance)
/// @dev This should be used as a central access control manager which other contracts use to check permissions
contract QuantConfig is
    AccessControlUpgradeable,
    OwnableUpgradeable,
    ITimelockedConfig
{
    address payable public override timelockController;

    mapping(bytes32 => address) public override protocolAddresses;
    bytes32[] public override configuredProtocolAddresses;

    mapping(bytes32 => uint256) public override protocolUints256;
    bytes32[] public override configuredProtocolUints256;

    mapping(bytes32 => bool) public override protocolBooleans;
    bytes32[] public override configuredProtocolBooleans;

    mapping(string => bytes32) public override quantRoles;
    bytes32[] public override configuredQuantRoles;

    function setProtocolAddress(bytes32 _protocolAddress, address _newValue)
        external
        override
        onlyOwner()
    {
        require(
            _protocolAddress != ProtocolValue.encode("priceRegistry") ||
                !protocolBooleans[ProtocolValue.encode("isPriceRegistrySet")],
            "QuantConfig: priceRegistry can only be set once"
        );

        protocolAddresses[_protocolAddress] = _newValue;
        configuredProtocolAddresses.push(_protocolAddress);
    }

    function setProtocolUint256(bytes32 _protocolUint256, uint256 _newValue)
        external
        override
        onlyOwner()
    {
        protocolUints256[_protocolUint256] = _newValue;
        configuredProtocolUints256.push(_protocolUint256);
    }

    function setProtocolBoolean(bytes32 _protocolBoolean, bool _newValue)
        external
        override
        onlyOwner()
    {
        require(
            _protocolBoolean != ProtocolValue.encode("isPriceRegistrySet") ||
                !protocolBooleans[ProtocolValue.encode("isPriceRegistrySet")],
            "QuantConfig: can only change isPriceRegistrySet once"
        );

        protocolBooleans[_protocolBoolean] = _newValue;
        configuredProtocolBooleans.push(_protocolBoolean);
    }

    function setProtocolRole(string calldata _protocolRole, address _roleAdmin)
        external
        override
        onlyOwner()
    {
        bytes32 role = keccak256(abi.encodePacked(_protocolRole));
        grantRole(role, _roleAdmin);
        quantRoles[_protocolRole] = role;
        configuredQuantRoles.push(role);
    }

    function setRoleAdmin(bytes32 role, bytes32 adminRole)
        external
        override
        onlyOwner()
    {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not admin");
        _setRoleAdmin(role, adminRole);
    }

    /// @notice Initializes the system roles and assign them to the given TimelockController address
    /// @param _timelockController Address of the TimelockController to receive the system roles
    /// @dev The TimelockController should have a Quant multisig as its sole proposer
    function initialize(address payable _timelockController)
        public
        override
        initializer
    {
        __AccessControl_init();
        __Ownable_init_unchained();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(DEFAULT_ADMIN_ROLE, _timelockController);
        // // On deployment, this role should be transferd to the OptionsFactory as its only admin
        bytes32 optionsControllerRole = keccak256("OPTIONS_CONTROLLER_ROLE");
        // quantRoles["OPTIONS_CONTROLLER_ROLE"] = optionsControllerRole;
        _setupRole(optionsControllerRole, _timelockController);
        _setupRole(optionsControllerRole, _msgSender());
        // quantRoles.push(optionsControllerRole);
        bytes32 oracleManagerRole = keccak256("ORACLE_MANAGER_ROLE");
        // quantRoles["ORACLE_MANAGER_ROLE"] = oracleManagerRole;
        _setupRole(oracleManagerRole, _timelockController);
        _setupRole(oracleManagerRole, _msgSender());
        timelockController = _timelockController;
    }
}