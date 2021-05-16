// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

interface ITimelockedConfig {
    function setProtocolAddress(bytes32, address) external;

    function setProtocolUint256(bytes32, uint256) external;

    function setProtocolBoolean(bytes32, bool) external;

    function setProtocolRole(string calldata, address) external;

    function initialize(address payable) external;

    function timelockController() external view returns (address payable);

    function protocolAddresses(bytes32) external view returns (address);

    function configuredProtocolAddresses(uint256)
        external
        view
        returns (bytes32);

    function protocolUints256(bytes32) external view returns (uint256);

    function configuredProtocolUints256(uint256)
        external
        view
        returns (bytes32);

    function protocolBooleans(bytes32) external view returns (bool);

    function configuredProtocolBooleans(uint256)
        external
        view
        returns (bytes32);

    function quantRoles(string calldata) external view returns (bytes32);

    function configuredQuantRoles(uint256) external view returns (bytes32);
}
