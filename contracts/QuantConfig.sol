// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.12;

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

    mapping(bytes32 => mapping(ProtocolValue.Type => bool))
        public
        override isProtocolValueSet;

    function setProtocolAddress(bytes32 _protocolAddress, address _newValue)
        external
        override
        onlyOwner
    {
        require(
            _protocolAddress != ProtocolValue.encode("priceRegistry") ||
                !protocolBooleans[ProtocolValue.encode("isPriceRegistrySet")],
            "QuantConfig: priceRegistry can only be set once"
        );
        address previousValue = protocolAddresses[_protocolAddress];
        protocolAddresses[_protocolAddress] = _newValue;
        configuredProtocolAddresses.push(_protocolAddress);
        isProtocolValueSet[_protocolAddress][ProtocolValue.Type.Address] = true;

        if (_protocolAddress == ProtocolValue.encode("priceRegistry")) {
            protocolBooleans[ProtocolValue.encode("isPriceRegistrySet")] = true;
        }

        emit SetProtocolAddress(_protocolAddress, previousValue, _newValue);
    }

    function setProtocolUint256(bytes32 _protocolUint256, uint256 _newValue)
        external
        override
        onlyOwner
    {
        uint256 previousValue = protocolUints256[_protocolUint256];
        protocolUints256[_protocolUint256] = _newValue;
        configuredProtocolUints256.push(_protocolUint256);
        isProtocolValueSet[_protocolUint256][ProtocolValue.Type.Uint256] = true;

        emit SetProtocolUint256(_protocolUint256, previousValue, _newValue);
    }

    function setProtocolBoolean(bytes32 _protocolBoolean, bool _newValue)
        external
        override
        onlyOwner
    {
        require(
            _protocolBoolean != ProtocolValue.encode("isPriceRegistrySet") ||
                !protocolBooleans[ProtocolValue.encode("isPriceRegistrySet")],
            "QuantConfig: can only change isPriceRegistrySet once"
        );
        bool previousValue = protocolBooleans[_protocolBoolean];
        protocolBooleans[_protocolBoolean] = _newValue;
        configuredProtocolBooleans.push(_protocolBoolean);
        isProtocolValueSet[_protocolBoolean][ProtocolValue.Type.Bool] = true;

        emit SetProtocolBoolean(_protocolBoolean, previousValue, _newValue);
    }

    function setProtocolRole(string calldata _protocolRole, address _roleAdmin)
        external
        override
        onlyOwner
    {
        _setProtocolRole(_protocolRole, _roleAdmin);
    }

    function setRoleAdmin(bytes32 role, bytes32 adminRole)
        external
        override
        onlyOwner
    {
        _setRoleAdmin(role, adminRole);

        emit SetRoleAdmin(role, adminRole);
    }

    function protocolAddressesLength()
        external
        view
        override
        returns (uint256)
    {
        return configuredProtocolAddresses.length;
    }

    function protocolUints256Length() external view override returns (uint256) {
        return configuredProtocolUints256.length;
    }

    function protocolBooleansLength() external view override returns (uint256) {
        return configuredProtocolBooleans.length;
    }

    function quantRolesLength() external view override returns (uint256) {
        return configuredQuantRoles.length;
    }

    /// @notice Initializes the system roles and assign them to the given TimelockController address
    /// @param _timelockController Address of the TimelockController to receive the system roles
    /// @dev The TimelockController should have a Quant multisig as its sole proposer
    function initialize(address payable _timelockController)
        public
        override
        initializer
    {
        require(
            _timelockController != address(0),
            "QuantConfig: invalid TimelockController address"
        );

        __AccessControl_init();
        __Ownable_init_unchained();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(DEFAULT_ADMIN_ROLE, _timelockController);

        string memory oracleManagerRole = "ORACLE_MANAGER_ROLE";
        _setProtocolRole(oracleManagerRole, _timelockController);
        _setProtocolRole(oracleManagerRole, _msgSender());
        timelockController = _timelockController;
    }

    function _setProtocolRole(string memory _protocolRole, address _roleAdmin)
        internal
    {
        bytes32 role = keccak256(abi.encodePacked(_protocolRole));
        grantRole(role, _roleAdmin);
        if (quantRoles[_protocolRole] == bytes32(0)) {
            quantRoles[_protocolRole] = role;
            configuredQuantRoles.push(role);
            isProtocolValueSet[role][ProtocolValue.Type.Role] = true;
        }

        emit SetProtocolRole(_protocolRole, role, _roleAdmin);
    }
}
