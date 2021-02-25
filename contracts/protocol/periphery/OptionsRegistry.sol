// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../options/QToken.sol";

/// @title A registry of options that can be added to by priveleged users
/// @notice An options registry which anyone can deploy a version of. This is independent from the Quant protocol.
contract OptionsRegistry is AccessControl {
    bytes32 public constant OPTION_MANAGER_ROLE =
        keccak256("OPTION_MANAGER_ROLE");

    struct OptionDetails {
        // address of qToken
        address qToken;
        // whether or not the option is shown in the frontend
        bool isVisible;
    }

    /// @notice underlying => list of options
    mapping(address => OptionDetails[]) public options;

    /// @notice exhaustive list of underlying assets in registry
    address[] public underlyingAssets;

    /// @param _admin administrator address which can manage options and assign option managers
    constructor(address _admin) {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(OPTION_MANAGER_ROLE, _admin);
    }

    function getOptionDetails(address _underlyingAsset, uint256 _index)
        external
        view
        returns (OptionDetails memory)
    {
        OptionDetails[] memory optionsArray = options[_underlyingAsset];
        require(
            optionsArray.length >= _index,
            "OptionsRegistry: Trying to access an option at an index that doesn't exist"
        );
        return optionsArray[_index];
    }

    function addOption(address _qToken) external {
        require(
            hasRole(OPTION_MANAGER_ROLE, msg.sender),
            "OptionsRegistry: Only an option manager can add an option"
        );

        address underlyingAsset = QToken(_qToken).underlyingAsset();

        if (options[underlyingAsset].length < 1) {
            //there are no existing underlying assets of that type yet
            underlyingAssets.push(underlyingAsset);
        }

        options[underlyingAsset].push(OptionDetails(_qToken, false));

        emit NewOption(
            underlyingAsset,
            _qToken,
            options[underlyingAsset].length - 1
        );
    }

    function makeOptionVisible(address _qToken, uint256 index) external {
        require(
            hasRole(OPTION_MANAGER_ROLE, msg.sender),
            "OptionsRegistry: Only an option manager can change visibility of an option"
        );

        address underlyingAsset = QToken(_qToken).underlyingAsset();

        options[underlyingAsset][index].isVisible = true;

        emit OptionVisibilityChanged(underlyingAsset, _qToken, index, true);
    }

    function makeOptionInvisible(address _qToken, uint256 index) external {
        require(
            hasRole(OPTION_MANAGER_ROLE, msg.sender),
            "OptionsRegistry: Only an option manager can change visibility of an option"
        );

        address underlyingAsset = QToken(_qToken).underlyingAsset();

        options[underlyingAsset][index].isVisible = false;

        emit OptionVisibilityChanged(underlyingAsset, _qToken, index, false);
    }

    function numberOfUnderlyingAssets() external view returns (uint256) {
        return underlyingAssets.length;
    }

    function numberOfOptionsForUnderlying(address _underlying)
        external
        view
        returns (uint256)
    {
        return options[_underlying].length;
    }

    event NewOption(address underlyingAsset, address qToken, uint256 index);

    event OptionVisibilityChanged(
        address underlyingAsset,
        address qToken,
        uint256 index,
        bool isVisible
    );
}
