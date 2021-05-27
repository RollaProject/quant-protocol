// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts-upgradeable/drafts/EIP712Upgradeable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IEIP712MetaTransaction.sol";

contract EIP712MetaTransaction is EIP712Upgradeable, IEIP712MetaTransaction {
    using SafeMath for uint256;

    struct MetaTransaction {
        uint256 nonce;
        address from;
        bytes functionSignature;
    }

    bytes32 private constant _META_TRANSACTION_TYPEHASH =
        keccak256(
            bytes(
                "MetaTransaction(uint256 nonce,address from,bytes functionSignature)"
            )
        );

    mapping(address => uint256) private _nonces;

    event MetaTransactionExecuted(
        address indexed userAddress,
        address payable indexed relayerAddress,
        bytes functionSignature
    );

    function executeMetaTransaction(
        address userAddress,
        bytes memory functionSignature,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external payable override returns (bytes memory) {
        bytes4 selector = _getSelector(functionSignature);
        require(selector != msg.sig, "can not have meta-meta-transactions");

        MetaTransaction memory metaTx =
            MetaTransaction({
                nonce: _nonces[userAddress],
                from: userAddress,
                functionSignature: functionSignature
            });

        require(
            _verify(userAddress, metaTx, r, s, v),
            "signer and signature don't match"
        );

        _nonces[userAddress] = _nonces[userAddress].add(1);

        // Append the userAddress at the end so that it can be extracted later
        // from the calling context (see _msgSender() below)
        (bool success, bytes memory returnData) =
            address(this).call(
                abi.encodePacked(functionSignature, userAddress)
            );

        require(success, "unsuccessful function call");
        emit MetaTransactionExecuted(
            userAddress,
            msg.sender,
            functionSignature
        );
        return returnData;
    }

    function getNonce(address user)
        external
        view
        override
        returns (uint256 nonce)
    {
        nonce = _nonces[user];
    }

    function initializeEIP712(string memory name, string memory version)
        public
        override
        initializer
    {
        __EIP712_init(name, version);
    }

    function _msgSender() internal view returns (address sender) {
        if (msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
                sender := and(
                    mload(add(array, index)),
                    0xffffffffffffffffffffffffffffffffffffffff
                )
            }
        } else {
            sender = msg.sender;
        }
        return sender;
    }

    function _verify(
        address user,
        MetaTransaction memory metaTx,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) internal view returns (bool) {
        require(metaTx.nonce == _nonces[user], "invalid nonce");

        address signer =
            ecrecover(_hashTypedDataV4(_hashMetaTransaction(metaTx)), v, r, s);

        require(signer != address(0), "invalid signature");

        return signer == user;
    }

    function _getSelector(bytes memory functionSignature)
        internal
        pure
        returns (bytes4 selector)
    {
        if (functionSignature.length == 0) {
            return 0x0;
        }

        assembly {
            selector := mload(add(functionSignature, 32))
        }
    }

    function _hashMetaTransaction(MetaTransaction memory metaTx)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    _META_TRANSACTION_TYPEHASH,
                    metaTx.nonce,
                    metaTx.from,
                    keccak256(metaTx.functionSignature)
                )
            );
    }
}
