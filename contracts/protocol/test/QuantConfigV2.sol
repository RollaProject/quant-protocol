// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

/// @title A central config for the quant system. Also acts as a central access control manager.
/// @notice For storing constants, variables and allowing them to be changed by the admin (governance)
/// @dev This should be used as a central access control manager which other contracts use to check permissions
contract QuantConfigV2 is AccessControl, Initializable {
    //this should be some admin/governance address
    address public admin;
    address public priceRegistry;
    address public oracleRegistry;
    uint256 public fee;

    bytes32 public constant OPTIONS_CONTROLLER_ROLE =
        keccak256("OPTIONS_CONTROLLER_ROLE");
    bytes32 public constant ORACLE_MANAGER_ROLE =
        keccak256("ORACLE_MANAGER_ROLE");
    bytes32 public constant PRICE_SUBMITTER_ROLE =
        keccak256("PRICE_SUBMITTER_ROLE");
    bytes32 public constant FALLBACK_PRICE_ROLE =
        keccak256("FALLBACK_PRICE_ROLE");

    uint256 public newV2StateVariable;

    /// @notice Set the protocol fee
    /// @dev Only accounts or contracts with the admin role should call this function
    /// @param _fee The new amount to set as the protocol fee
    function setFee(uint256 _fee) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not admin");
        fee = _fee;
    }

    /// @notice Initializes the system roles and assign them to the given admin address
    /// @param _admin Address to receive the system roles
    function initialize(address _admin) public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        // On deployment, this role should be transferd to the OptionsFactory as its only admin
        _setupRole(OPTIONS_CONTROLLER_ROLE, _admin);
        _setupRole(ORACLE_MANAGER_ROLE, _admin);
        admin = _admin;
    }
}
