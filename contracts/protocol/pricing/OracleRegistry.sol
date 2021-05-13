// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/IQuantConfig.sol";
import "../interfaces/IOracleRegistry.sol";

/// @title For centrally managing a list of oracle providers
/// @notice oracle provider registry for holding a list of oracle providers and their id
contract OracleRegistry is IOracleRegistry {
    using SafeMath for uint256;

    struct OracleInfo {
        bool isActive;
        uint256 oracleId;
    }

    /// @notice oracle address => OracleInfo
    mapping(address => OracleInfo) public oracleInfo;

    /// @notice exhaustive list of oracles in map
    address[] public oracles;

    /// @dev the oracle id of the last added oracle, if there is one. oracles start at id of 1
    uint256 private _currentId;

    /// @notice quant central configuration
    IQuantConfig public config;

    /// @param _config address of quant central configuration
    constructor(address _config) {
        config = IQuantConfig(_config);
    }

    /// @notice Add an oracle to the oracle registry which will generate an id. By default oracles are deactivated
    /// @param _oracle the address of the oracle
    /// @return the id of the oracle
    function addOracle(address _oracle) external override returns (uint256) {
        require(
            config.hasRole(
                config.quantRoles("ORACLE_MANAGER_ROLE"),
                msg.sender
            ),
            "OracleRegistry: Only an oracle admin can add an oracle"
        );
        require(
            oracleInfo[_oracle].oracleId == 0,
            "OracleRegistry: Oracle already exists in registry"
        );

        oracles.push(_oracle);
        _currentId = _currentId.add(1);

        emit AddedOracle(_oracle, _currentId);

        // TODO: Test this
        config.grantRole(config.quantRoles("PRICE_SUBMITTER_ROLE"), _oracle);

        oracleInfo[_oracle] = OracleInfo(false, _currentId);
        return oracles.length;
    }

    /// @notice Check if an oracle is registered in the registry
    /// @param _oracle the oracle to check
    function isOracleRegistered(address _oracle)
        external
        view
        override
        returns (bool)
    {
        return oracleInfo[_oracle].oracleId != 0;
    }

    /// @notice Check if an oracle is active i.e. are we allowed to create options with this oracle
    /// @param _oracle the oracle to check
    function isOracleActive(address _oracle)
        external
        view
        override
        returns (bool)
    {
        return oracleInfo[_oracle].isActive;
    }

    /// @notice Get the numeric id of an oracle
    /// @param _oracle the oracle to get the id of
    function getOracleId(address _oracle)
        external
        view
        override
        returns (uint256)
    {
        uint256 oracleId = oracleInfo[_oracle].oracleId;
        require(
            oracleId != 0,
            "OracleRegistry: Oracle doesn't exist in registry"
        );
        return oracleId;
    }

    /// @notice Deactivate an oracle so no new options can be created with this oracle address.
    /// @param _oracle the oracle to deactivate
    function deactivateOracle(address _oracle)
        external
        override
        returns (bool)
    {
        require(
            config.hasRole(
                config.quantRoles("ORACLE_MANAGER_ROLE"),
                msg.sender
            ),
            "OracleRegistry: Only an oracle admin can add an oracle"
        );
        require(
            oracleInfo[_oracle].isActive,
            "OracleRegistry: Oracle is already deactivated"
        );

        emit DeactivatedOracle(_oracle);

        return oracleInfo[_oracle].isActive = false;
    }

    /// @notice Activate an oracle so options can be created with this oracle address.
    /// @param _oracle the oracle to activate
    function activateOracle(address _oracle) external override returns (bool) {
        require(
            config.hasRole(
                config.quantRoles("ORACLE_MANAGER_ROLE"),
                msg.sender
            ),
            "OracleRegistry: Only an oracle admin can add an oracle"
        );
        require(
            !oracleInfo[_oracle].isActive,
            "OracleRegistry: Oracle is already activated"
        );

        emit ActivatedOracle(_oracle);

        return oracleInfo[_oracle].isActive = true;
    }

    /// @notice Get total number of oracles in registry
    /// @return the number of oracles in the registry
    function getOraclesLength() external view override returns (uint256) {
        return oracles.length;
    }

    event AddedOracle(address oracle, uint256 oracleId);

    event ActivatedOracle(address oracle);

    event DeactivatedOracle(address oracle);
}
