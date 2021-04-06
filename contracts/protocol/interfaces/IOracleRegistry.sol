// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

interface IOracleRegistry {
    function addOracle(address _oracle) external returns (uint256);

    function isOracleRegistered(address _oracle) external view returns (bool);

    function isOracleActive(address _oracle) external view returns (bool);

    function getOracleId(address _oracle) external view returns (uint256);

    function deactivateOracle(address _oracle) external returns (bool);

    function activateOracle(address _oracle) external returns (bool);

    function getOraclesLength() external view returns (uint256);
}
