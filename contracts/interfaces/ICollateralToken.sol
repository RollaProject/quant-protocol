// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/// @title Tokens representing a Quant user's short positions
/// @author Rolla
/// @notice Can be used by owners to claim their collateral
interface ICollateralToken {
    struct QTokensDetails {
        address underlyingAsset;
        address strikeAsset;
        address oracle;
        uint88 expiryTime;
        bool isCall;
        uint256 shortStrikePrice;
        uint256 longStrikePrice;
    }

    /// @notice event emitted when a new CollateralToken is created
    /// @param qTokenAddress address of the corresponding QToken
    /// @param qTokenAsCollateral QToken address of an option used as collateral in a spread
    /// @param id unique id of the created CollateralToken
    event CollateralTokenCreated(
        address indexed qTokenAddress,
        address qTokenAsCollateral,
        uint256 id
    );

    /// @notice Sets the the address for the OptionsFactory
    /// @param optionsFactory_ address of the OptionsFactory
    /// @dev This function will only be called once, in the Controller constructor, right after
    /// the CollateralToken contract is deployed with the Controller being its owner
    function setOptionsFactory(address optionsFactory_) external;

    /// @notice Create a new CollateralToken for a given QToken
    /// @param _qTokenAddress address of the corresponding QToken
    /// @return id the id for the CollateralToken created with the given arguments
    function createOptionCollateralToken(address _qTokenAddress)
        external
        returns (uint256 id);

    /// @notice Create a new CollateralToken for a given spread
    /// @param _qTokenAddress QToken address of an option being minted in a spread
    /// @param _qTokenAsCollateral QToken address of an option used as collateral in a spread
    /// @return id the id for the CollateralToken created with the given arguments
    function createSpreadCollateralToken(
        address _qTokenAddress,
        address _qTokenAsCollateral
    )
        external
        returns (uint256 id);

    /// @notice Mint CollateralTokens for a given account
    /// @param recipient address to receive the minted tokens
    /// @param amount amount of tokens to mint
    /// @param collateralTokenId id of the token to be minted
    function mintCollateralToken(
        address recipient,
        uint256 collateralTokenId,
        uint256 amount
    )
        external;

    /// @notice Mint CollateralTokens for a given account
    /// @param owner address to burn tokens from
    /// @param amount amount of tokens to burn
    /// @param collateralTokenId id of the token to be burned
    function burnCollateralToken(
        address owner,
        uint256 collateralTokenId,
        uint256 amount
    )
        external;

    /// @notice Set approval for all IDs by providing parameters to setApprovalForAll
    /// alongside a valid signature (r, s, v)
    /// @dev This method is implemented by following EIP-712: https://eips.ethereum.org/EIPS/eip-712
    /// @param owner     Address that wants to set operator status
    /// @param operator  Address to add to the set of authorized operators
    /// @param approved  True if the operator is approved, false to revoke approval
    /// @param nonce     Nonce valid for the owner at the time of the meta-tx execution
    /// @param deadline  Maximum unix timestamp at which the signature is still valid
    /// @param v         Last byte of the signed data
    /// @param r         The first 64 bytes of the signed data
    /// @param s         Bytes 64…128 of the signed data
    function metaSetApprovalForAll(
        address owner,
        address operator,
        bool approved,
        uint256 nonce,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external;

    /// @notice mapping of CollateralToken ids to their respective info struct
    function idToInfo(uint256) external view returns (address, address);

    /// @notice Returns a unique CollateralToken id based on its parameters
    /// @param _qToken the address of the corresponding QToken
    /// @param _qTokenAsCollateral QToken address of an option used as collateral in a spread
    /// @return id the id for the CollateralToken with the given arguments
    function getCollateralTokenId(address _qToken, address _qTokenAsCollateral)
        external
        pure
        returns (uint256 id);
}
