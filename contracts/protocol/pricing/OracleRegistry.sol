// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../QuantConfig.sol";

/// @title For centrally managing a list of oracle providers
/// @notice oracle provider registry for holding a list of oracle providers and their id
contract OracleProviderRegistry {
    /// @notice oracle => id
    mapping(address => uint256) public oracleIds;

    /// @notice exhaustive list of oracles in map
    address[] public oracles;

    /// @notice quant central configuration
    QuantConfig public config;

    /// @param _config address of quant central configuration
    constructor(
        address _config
    ) {
        config = QuantConfig(_config);
    }

    /// @notice Add an asset to the oracle registry which will generate an id
    /// @dev Once this is set for an asset, it can't be changed or removed
    /// @param _oracle the address of the oracle
    /// @return the id of the oracle
    function addOracle(
        address _oracle
    ) external returns (uint256) {
        require(
            config.hasRole(config.ORACLE_MANAGER_ROLE(), msg.sender),
            "OracleRegistry: Only an oracle admin can add an oracle"
        );
        require(oracleIds[_oracle] == 0, "OracleRegistry: Oracle already exists in registry");
        oracles.push(_oracle);
        oracleIds[_oracle] = oracles.length; //todo check this index is correct
        return oracles.length;
    }

    /// @notice Get total number of oracles in registry
    /// @return the number of oracles in the registry
    function getOraclesLength() external view returns(uint256) {
        return oracles.length;
    }
}