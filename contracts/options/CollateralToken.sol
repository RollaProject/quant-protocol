// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/IQuantConfig.sol";
import "../interfaces/ICollateralToken.sol";

/// @title Tokens representing a Quant user's short positions
/// @author Quant Finance
/// @notice Can be used by owners to claim their collateral
/// @dev This is a multi-token contract that implements the ERC1155 token standard:
/// https://eips.ethereum.org/EIPS/eip-1155
contract CollateralToken is ERC1155, ICollateralToken {
    using SafeMath for uint256;

    /// @dev stores metadata for a CollateralToken with an specific id
    /// @param qTokenAddress address of the corresponding QToken
    /// @param qTokenAsCollateral QToken address of an option used as collateral in a spread
    struct CollateralTokenInfo {
        address qTokenAddress;
        address qTokenAsCollateral;
    }

    /// @inheritdoc ICollateralToken
    IQuantConfig public override quantConfig;

    /// @inheritdoc ICollateralToken
    mapping(uint256 => CollateralTokenInfo) public override idToInfo;

    /// @inheritdoc ICollateralToken
    uint256[] public override collateralTokenIds;

    /// @inheritdoc ICollateralToken
    mapping(uint256 => uint256) public override tokenSupplies;

    /// @notice Initializes a new ERC1155 multi-token contract for representing
    /// users' short positions
    /// @param _quantConfig the address of the Quant system configuration contract
    constructor(address _quantConfig) ERC1155("URI") {
        quantConfig = IQuantConfig(_quantConfig);
    }

    /// @inheritdoc ICollateralToken
    function createCollateralToken(
        address _qTokenAddress,
        address _qTokenAsCollateral
    ) external override returns (uint256 id) {
        id = getCollateralTokenId(_qTokenAddress, _qTokenAsCollateral);

        require(
            quantConfig.hasRole(
                quantConfig.quantRoles("COLLATERAL_CREATOR_ROLE"),
                msg.sender
            ),
            "CollateralToken: Only a collateral creator can create new CollateralTokens"
        );

        require(
            idToInfo[id].qTokenAddress == address(0),
            "CollateralToken: this token has already been created"
        );

        idToInfo[id] = CollateralTokenInfo({
            qTokenAddress: _qTokenAddress,
            qTokenAsCollateral: _qTokenAsCollateral
        });

        collateralTokenIds.push(id);

        emit CollateralTokenCreated(
            _qTokenAddress,
            _qTokenAsCollateral,
            id,
            collateralTokenIds.length
        );
    }

    /// @inheritdoc ICollateralToken
    function mintCollateralToken(
        address recipient,
        uint256 collateralTokenId,
        uint256 amount
    ) external override {
        require(
            quantConfig.hasRole(
                quantConfig.quantRoles("COLLATERAL_MINTER_ROLE"),
                msg.sender
            ),
            "CollateralToken: Only a collateral minter can mint CollateralTokens"
        );

        tokenSupplies[collateralTokenId] = tokenSupplies[collateralTokenId].add(
            amount
        );

        emit CollateralTokenMinted(recipient, collateralTokenId, amount);

        _mint(recipient, collateralTokenId, amount, "");
    }

    /// @inheritdoc ICollateralToken
    function burnCollateralToken(
        address owner,
        uint256 collateralTokenId,
        uint256 amount
    ) external override {
        require(
            quantConfig.hasRole(
                quantConfig.quantRoles("COLLATERAL_BURNER_ROLE"),
                msg.sender
            ),
            "CollateralToken: Only a collateral burner can burn CollateralTokens"
        );
        _burn(owner, collateralTokenId, amount);

        tokenSupplies[collateralTokenId] = tokenSupplies[collateralTokenId].sub(
            amount
        );

        emit CollateralTokenBurned(owner, collateralTokenId, amount);
    }

    /// @inheritdoc ICollateralToken
    function mintCollateralTokenBatch(
        address recipient,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external override {
        require(
            quantConfig.hasRole(
                quantConfig.quantRoles("COLLATERAL_MINTER_ROLE"),
                msg.sender
            ),
            "CollateralToken: Only a collateral minter can mint CollateralTokens"
        );

        for (uint256 i = 0; i < ids.length; i++) {
            tokenSupplies[ids[i]] = tokenSupplies[ids[i]].add(amounts[i]);
            emit CollateralTokenMinted(recipient, ids[i], amounts[i]);
        }

        _mintBatch(recipient, ids, amounts, "");
    }

    /// @inheritdoc ICollateralToken
    function burnCollateralTokenBatch(
        address owner,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external override {
        require(
            quantConfig.hasRole(
                quantConfig.quantRoles("COLLATERAL_BURNER_ROLE"),
                msg.sender
            ),
            "CollateralToken: Only a collateral burner can burn CollateralTokens"
        );
        _burnBatch(owner, ids, amounts);

        for (uint256 i = 0; i < ids.length; i++) {
            tokenSupplies[ids[i]] = tokenSupplies[ids[i]].sub(amounts[i]);
            emit CollateralTokenBurned(owner, ids[i], amounts[i]);
        }
    }

    /// @inheritdoc ICollateralToken
    function getCollateralTokenId(address _qToken, address _qTokenAsCollateral)
        public
        pure
        override
        returns (uint256 id)
    {
        id = uint256(keccak256(abi.encodePacked(_qToken, _qTokenAsCollateral)));
    }
}
