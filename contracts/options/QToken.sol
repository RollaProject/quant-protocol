// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

import "../external/ERC20.sol";
import "../interfaces/IQToken.sol";

/// @title Token that represents a user's long position
/// @author Rolla
/// @notice Can be used by owners to exercise their options
/// @dev Every option long position is an ERC20 token: https://eips.ethereum.org/EIPS/eip-20
contract QToken is ERC20, IQToken {
    /// -----------------------------------------------------------------------
    /// Immutable parameters
    /// -----------------------------------------------------------------------

    /// @inheritdoc IQToken
    function underlyingAsset()
        public
        pure
        override
        returns (address _underlyingAsset)
    {
        return _getArgAddress(0x101);
    }

    /// @inheritdoc IQToken
    function strikeAsset()
        external
        pure
        override
        returns (address _strikeAsset)
    {
        return _getArgAddress(0x115);
    }

    /// @inheritdoc IQToken
    function oracle() public pure override returns (address _oracle) {
        return _getArgAddress(0x129);
    }

    /// @inheritdoc IQToken
    function expiryTime() public pure override returns (uint88 _expiryTime) {
        return _getArgUint88(0x13d);
    }

    /// @inheritdoc IQToken
    function isCall() external pure override returns (bool _isCall) {
        return _getArgBool(0x148);
    }

    /// @inheritdoc IQToken
    function strikePrice()
        external
        pure
        override
        returns (uint256 _strikePrice)
    {
        return _getArgUint256(0x149);
    }

    /// @inheritdoc IQToken
    function controller()
        public
        pure
        override
        returns (address _controller)
    {
        return _getArgAddress(0x169);
    }

    /// -----------------------------------------------------------------------
    /// ERC20 minting and burning logic
    /// -----------------------------------------------------------------------

    /// @notice Checks if the caller is the configured Quant Controller contract
    modifier onlyController() {
        require(msg.sender == controller(), "QToken: caller != controller");
        _;
    }

    /// @inheritdoc IQToken
    function mint(address account, uint256 amount)
        external
        override
        onlyController
    {
        _mint(account, amount);
    }

    /// @inheritdoc IQToken
    function burn(address account, uint256 amount)
        external
        override
        onlyController
    {
        _burn(account, amount);
    }
}
