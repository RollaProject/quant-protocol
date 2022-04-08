// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IOracleRegistry.sol";

/// @title For centrally managing a list of oracle providers
/// @author Rolla
/// @notice oracle provider registry for holding a list of oracle providers and their id
contract OracleRegistry is Ownable, IOracleRegistry {
    struct OracleInfo {
        bool isActive;
        uint256 oracleId;
    }

    /// @inheritdoc IOracleRegistry
    mapping(address => OracleInfo) public override oracleInfo;

    /// @inheritdoc IOracleRegistry
    address[] public override oracles;

    /// @inheritdoc IOracleRegistry
    function addOracle(address _oracle)
        external
        override
        onlyOwner
        returns (uint256)
    {
        require(
            oracleInfo[_oracle].oracleId == 0,
            "OracleRegistry: Oracle already exists in registry"
        );

        oracles.push(_oracle);

        uint256 currentId = oracles.length;

        emit AddedOracle(_oracle, currentId);

        oracleInfo[_oracle] = OracleInfo(false, currentId);
        return currentId;
    }

    /// @inheritdoc IOracleRegistry
    function deactivateOracle(address _oracle)
        external
        override
        onlyOwner
        returns (bool)
    {
        require(
            oracleInfo[_oracle].isActive,
            "OracleRegistry: Oracle is already deactivated"
        );

        emit DeactivatedOracle(_oracle);

        return oracleInfo[_oracle].isActive = false;
    }

    /// @inheritdoc IOracleRegistry
    function activateOracle(address _oracle)
        external
        override
        onlyOwner
        returns (bool)
    {
        require(
            !oracleInfo[_oracle].isActive,
            "OracleRegistry: Oracle is already activated"
        );

        emit ActivatedOracle(_oracle);

        return oracleInfo[_oracle].isActive = true;
    }

    /// @inheritdoc IOracleRegistry
    function isOracleRegistered(address _oracle)
        external
        view
        override
        returns (bool)
    {
        return oracleInfo[_oracle].oracleId != 0;
    }

    /// @inheritdoc IOracleRegistry
    function isOracleActive(address _oracle)
        external
        view
        override
        returns (bool)
    {
        return oracleInfo[_oracle].isActive;
    }

    /// @inheritdoc IOracleRegistry
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

    /// @inheritdoc IOracleRegistry
    function getOraclesLength() external view override returns (uint256) {
        return oracles.length;
    }
}
