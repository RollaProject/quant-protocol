// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@rari-capital/solmate/src/tokens/ERC1155.sol";
import "../interfaces/ICollateralToken.sol";

/// @title Tokens representing a Quant user's short positions
/// @author Rolla
/// @notice Can be used by holders to claim their collateral
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

    // Signature nonce per address
    mapping(address => uint256) public nonces;

    // base URI for ERC1155 token metadata
    string private _uri;

    // keccak256(
    //     "metaSetApprovalForAll(address cTokenOwner,address operator,bool approved,uint256 nonce,uint256 deadline)"
    // );
    bytes32 private constant _META_APPROVAL_TYPEHASH =
        0x8733d126a676f1e83270eccfbe576f65af55d3ff784c4dc4884be48932f47c81;

    // address of the OptionsFactory that will be able to create new CollateralTokens
    address private _optionsFactory;

    modifier onlyOwnerOrFactory() {
        require(
            msg.sender == owner() || msg.sender == _optionsFactory,
            "CollateralToken: caller is not owner or OptionsFactory"
        );

        _;
    }

    /// @notice Initializes a new ERC1155 multi-token contract for representing
    /// users' short positions
    /// @param _name name for the domain typehash in EIP712 meta transactions
    /// @param _version version for the domain typehash in EIP712 meta transactions
    /// @param uri_ URI for ERC1155 tokens metadata
    constructor(
        string memory _name,
        string memory _version,
        string memory uri_
    ) EIP712(_name, _version) {
        _uri = uri_;
    }

    /// @inheritdoc ICollateralToken
    function setOptionsFactory(address optionsFactory_) external onlyOwner {
        _optionsFactory = optionsFactory_;
    }

    /// @inheritdoc ICollateralToken
    function createOptionCollateralToken(address _qTokenAddress)
        external
        override
        onlyOwnerOrFactory
        returns (uint256 id)
    {
        id = getCollateralTokenId(_qTokenAddress, address(0));

        idToInfo[id] = CollateralTokenInfo({
            qTokenAddress: _qTokenAddress,
            qTokenAsCollateral: address(0)
        });

        emit CollateralTokenCreated(_qTokenAddress, address(0), id);
    }

    /// @inheritdoc ICollateralToken
    function createSpreadCollateralToken(
        address _qTokenAddress,
        address _qTokenAsCollateral
    ) external override onlyOwnerOrFactory returns (uint256 id) {
        id = getCollateralTokenId(_qTokenAddress, _qTokenAsCollateral);

        require(
            _qTokenAddress != _qTokenAsCollateral,
            "CollateralToken: Can only create a collateral token with different tokens"
        );

        idToInfo[id] = CollateralTokenInfo({
            qTokenAddress: _qTokenAddress,
            qTokenAsCollateral: _qTokenAsCollateral
        });

        emit CollateralTokenCreated(_qTokenAddress, _qTokenAsCollateral, id);
    }

    /// @inheritdoc ICollateralToken
    function mintCollateralToken(
        address recipient,
        uint256 collateralTokenId,
        uint256 amount
    ) external override onlyOwner {
        _mint(recipient, collateralTokenId, amount, "");
    }

    /// @inheritdoc ICollateralToken
    function burnCollateralToken(
        address cTokenOwner,
        uint256 collateralTokenId,
        uint256 amount
    ) external override onlyOwner {
        _burn(cTokenOwner, collateralTokenId, amount);
    }

    /// @inheritdoc ICollateralToken
    function metaSetApprovalForAll(
        address cTokenOwner,
        address operator,
        bool approved,
        uint256 nonce,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        require(nonce == nonces[cTokenOwner], "CollateralToken: invalid nonce");

        // solhint-disable-next-line not-rely-on-time
        require(
            deadline >= block.timestamp,
            "CollateralToken: expired deadline"
        );

        bytes32 structHash = keccak256(
            abi.encode(
                _META_APPROVAL_TYPEHASH,
                cTokenOwner,
                operator,
                approved,
                nonce,
                deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = hash.recover(v, r, s);

        require(signer == cTokenOwner, "CollateralToken: invalid signature");

        unchecked {
            nonces[cTokenOwner]++;
        }

        isApprovedForAll[cTokenOwner][operator] = approved;

        emit ApprovalForAll(cTokenOwner, operator, approved);
    }

    /// @notice Gets the URI for the CollateralToken metadata
    /// @return uri_ URI for the CollateralToken metadata
    function uri(uint256) public view override returns (string memory uri_) {
        uri_ = _uri;
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
