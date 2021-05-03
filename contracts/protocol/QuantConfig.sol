// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts/access/TimelockController.sol";

/// @title A central config for the quant system. Also acts as a central access control manager.
/// @notice For storing constants, variables and allowing them to be changed by the admin (governance)
/// @dev This should be used as a central access control manager which other contracts use to check permissions
contract QuantConfig is AccessControl, Initializable {
    //this should be some admin/governance address
    address payable public timelockController;
    address public priceRegistry;
    address public oracleRegistry;
    address public assetsRegistry;
    uint256 public maxOptionsDuration;
    bool private _priceRegistrySetted;

    mapping(bytes32 => address) public protocolAddresses;
    mapping(bytes32 => uint256) public protocolUints256;
    mapping(bytes32 => bool) public protocolBooleans;
    mapping(string => bytes32) public quantRoles;

    modifier onlyTimelockExecutor() {
        require(
            hasRole(
                TimelockController(timelockController).EXECUTOR_ROLE(),
                _msgSender()
            ),
            "TimelockController: sender requires permission"
        );
        _;
    }

    function setProtocolAddress(bytes32 _protocolAddress, address _newValue)
        external
        onlyTimelockExecutor()
    {
        protocolAddresses[_protocolAddress] = _newValue;
    }

    function setProtocolUint256(bytes32 _protocolUint256, uint256 _newValue)
        external
        onlyTimelockExecutor()
    {
        protocolUints256[_protocolUint256] = _newValue;
    }

    function setProtocolBoolean(bytes32 _protocolBoolean, bool _newValue)
        external
        onlyTimelockExecutor()
    {
        protocolBooleans[_protocolBoolean] = _newValue;
    }

    /// @notice Initializes the system roles and assign them to the given TimelockController address
    /// @param _timelockController Address of the TimelockController to receive the system roles
    /// @dev The TimelockController should have a Quant multisig as its sole proposer
    function initialize(address payable _timelockController)
        public
        initializer
    {
        _setupRole(DEFAULT_ADMIN_ROLE, _timelockController);
        // On deployment, this role should be transferd to the OptionsFactory as its only admin
        bytes32 optionsControllerRole = keccak256("OPTIONS_CONTROLLER_ROLE");
        quantRoles["OPTIONS_CONTROLLER_ROLE"] = optionsControllerRole;
        _setupRole(optionsControllerRole, _timelockController);
        bytes32 oracleManagerRole = keccak256("ORACLE_MANAGER_ROLE");
        quantRoles["ORACLE_MANAGER_ROLE"] = oracleManagerRole;
        _setupRole(oracleManagerRole, _timelockController);
        timelockController = _timelockController;
    }
}
