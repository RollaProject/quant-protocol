// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

/// @title A central config for the quant system. Also acts as a central access control manager.
/// @notice For storing constants, variables and allowing them to be changed by the admin (governance)
/// @dev This should be used as a central access control manager which other contracts use to check permissions
contract QuantConfig is AccessControl, Initializable {
    //this should be some admin/governance address
    address public timelockController;
    address public priceRegistry;
    address public oracleRegistry;
    address public assetsRegistry;
    uint256 public fee;
    bool private _priceRegistrySetted;

    bytes32 public constant ORACLE_MANAGER_ROLE =
        keccak256("ORACLE_MANAGER_ROLE");
    bytes32 public constant PRICE_SUBMITTER_ROLE =
        keccak256("PRICE_SUBMITTER_ROLE");
    bytes32 public constant PRICE_SUBMITTER_ROLE_ADMIN =
        keccak256("PRICE_SUBMITTER_ROLE_ADMIN");
    bytes32 public constant FALLBACK_PRICE_ROLE =
        keccak256("FALLBACK_PRICE_ROLE");
    bytes32 public constant OPTIONS_MINTER_ROLE =
        keccak256("OPTIONS_MINTER_ROLE");
    bytes32 public constant OPTIONS_BURNER_ROLE =
        keccak256("OPTIONS_BURNER_ROLE");
    bytes32 public constant COLLATERAL_MINTER_ROLE =
        keccak256("COLLATERAL_MINTER_ROLE");
    bytes32 public constant COLLATERAL_BURNER_ROLE =
        keccak256("COLLATERAL_BURNER_ROLE");
    bytes32 public constant ASSET_REGISTRY_MANAGER_ROLE =
        keccak256("ASSET_REGISTRY_MANAGER_ROLE");
    bytes32 public constant COLLATERAL_CREATOR_ROLE =
        keccak256("COLLATERAL_CREATOR_ROLE");

    /// @notice Set the protocol fee
    /// @dev Only accounts or contracts with the admin role should call this function
    /// @param _fee The new amount to set as the protocol fee
    function setFee(uint256 _fee) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not admin");
        fee = _fee;
    }

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
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not admin");
        assetsRegistry = _assetsRegistry;
    }

    function setRoleAdmin(bytes32 role, bytes32 adminRole) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not admin");
        _setRoleAdmin(role, adminRole);
    }

    function setupRole(bytes32 role, address roleReceiver) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not admin");
        _setupRole(role, roleReceiver);
    }

    /// @notice Initializes the system roles and assign them to the given admin address
    function initialize(address _timelockController) public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _timelockController);
        // On deployment, this role should be transferd to the OptionsFactory as its only admin
        // _setupRole(OPTIONS_CONTROLLER_ROLE, _admin);
        // _setupRole(ORACLE_MANAGER_ROLE, _admin);
        // _setupRole(FALLBACK_PRICE_ROLE, _admin);
        // _setupRole(ASSET_REGISTRY_MANAGER_ROLE, _admin);
        // _setupRole(COLLATERAL_CREATOR_ROLE, _admin);
        // _setupRole(COLLATERAL_MINTER_ROLE, _admin);
        // _setupRole(COLLATERAL_BURNER_ROLE, _admin);
        // _setupRole(OPTIONS_MINTER_ROLE, _admin);
        // _setupRole(OPTIONS_BURNER_ROLE, _admin);
        timelockController = _timelockController;
    }
}
