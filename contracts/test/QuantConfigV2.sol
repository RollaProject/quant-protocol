// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

/// @title A central config for the quant system. Also acts as a central access control manager.
/// @notice For storing constants, variables and allowing them to be changed by the admin (governance)
/// @dev This should be used as a central access control manager which other contracts use to check permissions
contract QuantConfigV2 is AccessControl, Initializable {
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

    bytes32 public constant OPTIONS_CONTROLLER_ROLE =
        keccak256("OPTIONS_CONTROLLER_ROLE");
    bytes32 public constant ORACLE_MANAGER_ROLE =
        keccak256("ORACLE_MANAGER_ROLE");
    bytes32 public constant PRICE_SUBMITTER_ROLE =
        keccak256("PRICE_SUBMITTER_ROLE");

    uint256 public newV2StateVariable;

    /// @notice Set the protocol's price registry
    /// @dev Can only be called once, and by accounts or contracts with the admin role
    /// @param _priceRegistry address of the PriceRegistry to be used by the protocol
    function setPriceRegistry(address _priceRegistry) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not admin");
        require(!_priceRegistrySetted, "Can only set the price registry once");
        priceRegistry = _priceRegistry;
        _priceRegistrySetted = true;
    }

    /// @notice Set the protocol assets registry
    /// @dev Only accounts or contracts with the admin role should call this contract
    /// @param _assetsRegistry address of the AssetsRegistry to be used by the protocol
    function setAssetsRegistry(address _assetsRegistry) external {
        require(
            hasRole(OPTIONS_CONTROLLER_ROLE, msg.sender),
            "Caller is not admin"
        );
        assetsRegistry = _assetsRegistry;
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
        _setupRole(OPTIONS_CONTROLLER_ROLE, _timelockController);
        _setupRole(ORACLE_MANAGER_ROLE, _timelockController);
        timelockController = _timelockController;
    }
}
