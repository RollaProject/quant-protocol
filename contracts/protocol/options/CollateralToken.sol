// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../QuantConfig.sol";

/// @title Tokens representing a Quant user's short positions
/// @author Quant Finance
/// @notice Can be used by owners to claim their collateral
/// @dev This is a multi-token contract that implements the ERC1155 token standard:
/// https://eips.ethereum.org/EIPS/eip-1155
contract CollateralToken is ERC1155 {
    using SafeMath for uint256;

    /// @dev stores metadata for a CollateralToken with an specific id
    /// @param qTokenAddress address of the corresponding QToken
    /// @param collateralizedFrom initial spread collateral
    struct CollateralTokenInfo {
        address qTokenAddress;
        uint256 collateralizedFrom;
    }

    /// @notice The Quant system config
    QuantConfig public quantConfig;

    /// @notice mapping of CollateralToken ids to their respective info struct
    mapping(uint256 => CollateralTokenInfo) public idToInfo;

    /// @notice array of all the created CollateralToken ids
    uint256[] public collateralTokensIds;

    /// @notice mapping from token ids to their supplies
    mapping(uint256 => uint256) public tokenSupplies;

    /// @notice event emitted when a new CollateralToken is created
    /// @param qTokenAddress address of the corresponding QToken
    /// @param collateralizedFrom initial spread collateral
    /// @param id unique id of the created CollateralToken
    /// @param allCollateralTokensLength the updated number of already created CollateralTokens
    event CollateralTokenCreated(
        address indexed qTokenAddress,
        uint256 collateralizedFrom,
        uint256 id,
        uint256 allCollateralTokensLength
    );

    /// @notice event emitted when CollateralTokens are minted
    /// @param recipient address that received the minted CollateralTokens
    /// @param id unique id of the minted CollateralToken
    /// @param amount the amount of CollateralToken minted
    event CollateralTokenMinted(
        address indexed recipient,
        uint256 indexed id,
        uint256 amount
    );

    /// @notice event emitted when CollateralTokens are burned
    /// @param owner address that the CollateralToken was burned from
    /// @param id unique id of the burned CollateralToken
    /// @param amount the amount of CollateralToken burned
    event CollateralTokenBurned(
        address indexed owner,
        uint256 indexed id,
        uint256 amount
    );

    /// @notice Initializes a new ERC1155 multi-token contract for representing
    /// users' short positions
    /// @param _quantConfig the address of the Quant system configuration contract
    constructor(address _quantConfig) ERC1155("URI") {
        quantConfig = QuantConfig(_quantConfig);
    }

    /// @notice Create new CollateralTokens
    /// @param _qTokenAddress address of the corresponding QToken
    /// @param _collateralizedFrom initial spread collateral
    /// @return id the id for the CollateralToken created with the given arguments
    function createCollateralToken(
        address _qTokenAddress,
        uint256 _collateralizedFrom
    ) external returns (uint256 id) {
        id = getCollateralTokenId(_qTokenAddress, _collateralizedFrom);

        require(
            quantConfig.hasRole(
                quantConfig.OPTIONS_CONTROLLER_ROLE(),
                msg.sender
            ),
            "CollateralToken: Only the OptionsFactory can create new CollateralTokens"
        );

        require(
            idToInfo[id].qTokenAddress == address(0),
            "CollateralToken: this token has already been created"
        );

        idToInfo[id] = CollateralTokenInfo({
            qTokenAddress: _qTokenAddress,
            collateralizedFrom: _collateralizedFrom
        });

        collateralTokensIds.push(id);

        emit CollateralTokenCreated(
            _qTokenAddress,
            _collateralizedFrom,
            id,
            collateralTokensIds.length
        );
    }

    /// @notice Mint CollateralTokens for a given account
    /// @param recipient address to receive the minted tokens
    /// @param amount amount of tokens to mint
    /// @param collateralTokenId id of the token to be minted
    function mintCollateralToken(
        address recipient,
        uint256 collateralTokenId,
        uint256 amount
    ) external {
        require(
            quantConfig.hasRole(
                quantConfig.OPTIONS_CONTROLLER_ROLE(),
                msg.sender
            ),
            "CollateralToken: Only the OptionsFactory can mint CollateralTokens"
        );

        tokenSupplies[collateralTokenId] = tokenSupplies[collateralTokenId].add(
            amount
        );

        emit CollateralTokenMinted(recipient, collateralTokenId, amount);

        _mint(recipient, collateralTokenId, amount, "");
    }

    /// @notice Mint CollateralTokens for a given account
    /// @param owner address to burn tokens from
    /// @param amount amount of tokens to burn
    /// @param collateralTokenId id of the token to be burned
    function burnCollateralToken(
        address owner,
        uint256 collateralTokenId,
        uint256 amount
    ) external {
        require(
            quantConfig.hasRole(
                quantConfig.OPTIONS_CONTROLLER_ROLE(),
                msg.sender
            ),
            "CollateralToken: Only the OptionsFactory can burn CollateralTokens"
        );
        _burn(owner, collateralTokenId, amount);

        tokenSupplies[collateralTokenId] = tokenSupplies[collateralTokenId].sub(
            amount
        );

        emit CollateralTokenBurned(owner, collateralTokenId, amount);
    }

    /// @notice Batched minting of multiple CollateralTokens for a given account
    /// @dev Should be used when minting multiple CollateralTokens for a single user,
    /// i.e., when a user buys more than one short position through the interface
    /// @param recipient address to receive the minted tokens
    /// @param ids array of CollateralToken ids to be minted
    /// @param amounts array of amounts of tokens to be minted
    /// @dev ids and amounts must have the same length
    function mintCollateralTokenBatch(
        address recipient,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external {
        require(
            quantConfig.hasRole(
                quantConfig.OPTIONS_CONTROLLER_ROLE(),
                msg.sender
            ),
            "CollateralToken: Only the OptionsFactory can mint CollateralTokens"
        );

        for (uint256 i = 0; i < ids.length; i++) {
            tokenSupplies[ids[i]] = tokenSupplies[ids[i]].add(amounts[i]);
            emit CollateralTokenMinted(recipient, ids[i], amounts[i]);
        }

        _mintBatch(recipient, ids, amounts, "");
    }

    /// @notice Batched burning of of multiple CollateralTokens from a given account
    /// @dev Should be used when burning multiple CollateralTokens for a single user,
    /// i.e., when a user sells more than one short position through the interface
    /// @param owner address to burn tokens from
    /// @param ids array of CollateralToken ids to be burned
    /// @param amounts array of amounts of tokens to be burned
    /// @dev ids and amounts shoud have the same length
    function burnCollateralTokenBatch(
        address owner,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external {
        require(
            quantConfig.hasRole(
                quantConfig.OPTIONS_CONTROLLER_ROLE(),
                msg.sender
            ),
            "CollateralToken: Only the OptionsFactory can burn CollateralTokens"
        );
        _burnBatch(owner, ids, amounts);

        for (uint256 i = 0; i < ids.length; i++) {
            tokenSupplies[ids[i]] = tokenSupplies[ids[i]].sub(amounts[i]);
            emit CollateralTokenBurned(owner, ids[i], amounts[i]);
        }
    }

    /// @notice Returns a unique CollateralToken id based on its parameters
    /// @param _qToken the address of the corresponding QToken
    /// @param _collateralizedFrom initial spread collateral
    /// @return id the id for the CollateralToken with the given arguments
    function getCollateralTokenId(address _qToken, uint256 _collateralizedFrom)
        public
        pure
        returns (uint256 id)
    {
        id = uint256(keccak256(abi.encodePacked(_qToken, _collateralizedFrom)));
    }
}
