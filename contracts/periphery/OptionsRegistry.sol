// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.0;
pragma abicoder v2;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../options/QToken.sol";
import "../interfaces/IOptionsRegistry.sol";

/// @title A registry of options that can be added to by priveleged users
/// @notice An options registry which anyone can deploy a version of. This is independent from the Quant protocol.
contract OptionsRegistry is AccessControl, IOptionsRegistry {
    struct RegistryDetails {
        address underlying;
        uint256 index;
    }

    bytes32 public constant OPTION_MANAGER_ROLE =
        keccak256("OPTION_MANAGER_ROLE");

    /// @notice underlying => list of options
    mapping(address => OptionDetails[]) public options;
    mapping(address => RegistryDetails) private _registryDetails;

    /// @notice exhaustive list of underlying assets in registry
    address[] public underlyingAssets;

    /// @param _admin administrator address which can manage options and assign option managers
    constructor(address _admin) {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(OPTION_MANAGER_ROLE, _admin);
    }

    function addOption(address _qToken) external override {
        require(
            hasRole(OPTION_MANAGER_ROLE, msg.sender),
            "OptionsRegistry: Only an option manager can add an option"
        );
        require(
            _registryDetails[_qToken].underlying == address(0),
            "OptionsRegistry: qToken address already added"
        );

        address underlyingAsset = QToken(_qToken).underlyingAsset();

        if (options[underlyingAsset].length < 1) {
            //there are no existing underlying assets of that type yet
            underlyingAssets.push(underlyingAsset);
        }

        options[underlyingAsset].push(OptionDetails(_qToken, false));
        _registryDetails[_qToken].underlying = underlyingAsset;
        _registryDetails[_qToken].index = options[underlyingAsset].length -1;

        emit NewOption(
            underlyingAsset,
            _qToken,
            options[underlyingAsset].length - 1
        );
    }

    function makeOptionVisible(address _qToken, uint256 index)
        external
        override
    {
        require(
            hasRole(OPTION_MANAGER_ROLE, msg.sender),
            "OptionsRegistry: Only an option manager can change visibility of an option"
        );

        address underlyingAsset = QToken(_qToken).underlyingAsset();

        options[underlyingAsset][index].isVisible = true;

        emit OptionVisibilityChanged(underlyingAsset, _qToken, index, true);
    }

    function makeOptionInvisible(address _qToken, uint256 index)
        external
        override
    {
        require(
            hasRole(OPTION_MANAGER_ROLE, msg.sender),
            "OptionsRegistry: Only an option manager can change visibility of an option"
        );

        address underlyingAsset = QToken(_qToken).underlyingAsset();

        options[underlyingAsset][index].isVisible = false;

        emit OptionVisibilityChanged(underlyingAsset, _qToken, index, false);
    }

    function getOptionDetails(address _underlyingAsset, uint256 _index)
        external
        view
        override
        returns (OptionDetails memory)
    {
        OptionDetails[] memory optionsArray = options[_underlyingAsset];
        require(
            optionsArray.length >= _index,
            "OptionsRegistry: Trying to access an option at an index that doesn't exist"
        );
        return optionsArray[_index];
    }

    function numberOfUnderlyingAssets()
        external
        view
        override
        returns (uint256)
    {
        return underlyingAssets.length;
    }

    function numberOfOptionsForUnderlying(address _underlying)
        external
        view
        override
        returns (uint256)
    {
        return options[_underlying].length;
    }

    function getRegistryDetails(address qTokenAddress) 
        external 
        view 
        returns (RegistryDetails memory)
    {
        RegistryDetails memory qTokenDetails = _registryDetails[qTokenAddress];
        require(
            qTokenDetails.underlying != address(0),
            "qToken not registered"
        );
        return qTokenDetails;
    }
}
