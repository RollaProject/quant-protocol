// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../external/openzeppelin/ERC1155.sol";
import "../interfaces/ICollateralToken.sol";
import "../interfaces/IQToken.sol";

/// @title Tokens representing a Quant user's short positions
/// @author Rolla
/// @notice Can be used by owners to claim their collateral
/// @dev This is a multi-token contract that implements the ERC1155 token standard:
/// https://eips.ethereum.org/EIPS/eip-1155
contract CollateralToken is ERC1155, ICollateralToken, EIP712, Ownable {
    using ECDSA for bytes32;

    /// @dev stores metadata for a CollateralToken with an specific id
    /// @param qTokenAddress address of the corresponding QToken
    /// @param qTokenAsCollateral QToken address of an option used as collateral in a spread
    struct CollateralTokenInfo {
        address qTokenAddress;
        address qTokenAsCollateral;
    }

    /// @inheritdoc ICollateralToken
    mapping(uint256 => CollateralTokenInfo) public override idToInfo;

    // uint256[] public override collateralTokenIds;

    // Signature nonce per address
    mapping(address => uint256) public nonces;

    // keccak256(
    //     "metaSetApprovalForAll(address owner,address operator,bool approved,uint256 nonce,uint256 deadline)"
    // );
    bytes32 private constant _META_APPROVAL_TYPEHASH =
        0xf8f9aaf28cf20cd45b21061d07505fa1da285124284441ea655b9eb837ed89b7;

    address private _optionsFactory;

    /// @notice Initializes a new ERC1155 multi-token contract for representing
    /// users' short positions
    /// @param _name name for the domain typehash in EIP712 meta transactions
    /// @param _version version for the domain typehash in EIP712 meta transactions
    /// @param uri_ URI for ERC1155 tokens metadata
    constructor(
        string memory _name,
        string memory _version,
        string memory uri_
    )
        ERC1155(uri_)
        EIP712(_name, _version)
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function setOptionsFactory(address optionsFactory_) external onlyOwner {
        _optionsFactory = optionsFactory_;
    }

    /// @inheritdoc ICollateralToken
    function createCollateralToken(
        address _qTokenAddress,
        address _qTokenAsCollateral
    ) external override returns (uint256 id) {
        id = getCollateralTokenId(_qTokenAddress, _qTokenAsCollateral);

        require(
            msg.sender == owner() || msg.sender == _optionsFactory,
            "CollateralToken: caller is not owner or OptionsFactory"
        );

        require(
            _qTokenAddress != _qTokenAsCollateral,
            "CollateralToken: Can only create a collateral token with different tokens"
        );

        // require(
        //     idToInfo[id].qTokenAddress == address(0),
        //     "CollateralToken: this token has already been created"
        // );

        idToInfo[id] = CollateralTokenInfo({
            qTokenAddress: _qTokenAddress,
            qTokenAsCollateral: _qTokenAsCollateral
        });

        // collateralTokenIds.push(id);

        emit CollateralTokenCreated(_qTokenAddress, _qTokenAsCollateral, id);
    }

    /// @inheritdoc ICollateralToken
    function mintCollateralToken(
        address recipient,
        uint256 collateralTokenId,
        uint256 amount
    ) external override onlyOwner {
        _mint(recipient, collateralTokenId, amount, "");
        emit CollateralTokenMinted(recipient, collateralTokenId, amount);
    }

    /// @inheritdoc ICollateralToken
    function burnCollateralToken(
        address owner,
        uint256 collateralTokenId,
        uint256 amount
    ) external override onlyOwner {
        _burn(owner, collateralTokenId, amount);
        emit CollateralTokenBurned(owner, collateralTokenId, amount);
    }

    /// @inheritdoc ICollateralToken
    function mintCollateralTokenBatch(
        address recipient,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external override onlyOwner {
        uint256 length = ids.length;
        for (uint256 i = 0; i < length; ) {
            emit CollateralTokenMinted(recipient, ids[i], amounts[i]);
            unchecked {
                ++i;
            }
        }

        _mintBatch(recipient, ids, amounts, "");
    }

    /// @inheritdoc ICollateralToken
    function burnCollateralTokenBatch(
        address owner,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external override onlyOwner {
        _burnBatch(owner, ids, amounts);

        uint256 length = ids.length;
        for (uint256 i = 0; i < length; ) {
            emit CollateralTokenBurned(owner, ids[i], amounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc ICollateralToken
    function metaSetApprovalForAll(
        address owner,
        address operator,
        bool approved,
        uint256 nonce,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        require(nonce == nonces[owner], "CollateralToken: invalid nonce");

        // solhint-disable-next-line not-rely-on-time
        require(
            deadline >= block.timestamp,
            "CollateralToken: expired deadline"
        );

        bytes32 structHash = keccak256(
            abi.encode(
                _META_APPROVAL_TYPEHASH,
                owner,
                operator,
                approved,
                nonce,
                deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = hash.recover(v, r, s);

        require(signer == owner, "CollateralToken: invalid signature");

        unchecked {
            nonces[owner]++;
        }
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /// @inheritdoc ICollateralToken
    // function getCollateralTokensLength()
    //     external
    //     view
    //     override
    //     returns (uint256)
    // {
    //     return collateralTokenIds.length;
    // }

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
