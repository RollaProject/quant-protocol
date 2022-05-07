// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20 as OzERC20Interface} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";

/// @title Token that represents a user's long position
/// @author Rolla
/// @notice Can be used by owners to exercise their options
/// @dev Every option long position is an ERC20 token: https://eips.ethereum.org/EIPS/eip-20
interface IQToken {
    /// @notice event emitted when QTokens are minted
    /// @param account account the QToken was minted to
    /// @param amount the amount of QToken minted
    event QTokenMinted(address indexed account, uint256 amount);

    /// @notice event emitted when QTokens are burned
    /// @param account account the QToken was burned from
    /// @param amount the amount of QToken burned
    event QTokenBurned(address indexed account, uint256 amount);

    /// @notice mint option token for an account
    /// @param account account to mint token to
    /// @param amount amount to mint
    function mint(address account, uint256 amount) external;

    /// @notice burn option token from an account.
    /// @param account account to burn token from
    /// @param amount amount to burn
    function burn(address account, uint256 amount) external;

    /// @dev Address of the underlying asset. WETH for ethereum options.
    function underlyingAsset() external pure returns (address);

    /// @dev Address of the strike asset. Quant Web options always use USDC.
    function strikeAsset() external pure returns (address);

    /// @dev Address of the oracle to be used with this option
    function oracle() external pure returns (address);

    /// @dev The strike price for the token with the strike asset precision.
    function strikePrice() external pure returns (uint256);

    /// @dev UNIX time for the expiry of the option
    function expiryTime() external pure returns (uint88);

    /// @dev True if the option is a CALL. False if the option is a PUT.
    function isCall() external pure returns (bool);

    /// @dev Address of the Controller contract, which can mint and burn QTokens.
    function controller() external pure returns (address);
}
