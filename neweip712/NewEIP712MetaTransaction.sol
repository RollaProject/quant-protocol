// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma abicoder v2;

import "@openzeppelin/contracts/drafts/EIP712.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

// import "./interfaces/IEIP712MetaTransaction.sol";

contract NewEIP712MetaTransaction is EIP712 {
    using SafeMath for uint256;

    // struct MetaTransaction {
    //     uint256 nonce;
    //     address from;
    //     Action actions;
    // }

    struct MetaAction {
        uint256 nonce;
        address from;
        Action actions;
    }
    struct Action {
        string actionName;
        address from;
        address to;
        uint256 amount;
    }

    bytes32 private constant META_TRANSACTION_TYPEHASH =
        keccak256(
            "MetaTransaction(uint256 nonce,address from,bytes functionSignature)"
        );
    bytes32 private constant META_ACTION_TYPEHASH =
        keccak256(
            "MetaAction(uint256 nonce,address from,(string actionName,address from,address to,uint256 amount) action)"
        );
    bytes32 private constant ACTION_TYPEHASH =
        keccak256(
            "Action(string actionName,address from,address to,uint256 amount)"
        );

    mapping(address => uint256) private _nonces;

    event MetaTransactionExecuted(
        address indexed userAddress,
        address payable indexed relayerAddress,
        bytes functionSignature
    );

    event MetaTransactionVerified(bool isValid, bytes32 r, bytes32 s, uint8 v);

    constructor(string memory name, string memory version)
        EIP712(name, version)
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function hashMetaAction(MetaAction memory metaAction)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    META_TRANSACTION_TYPEHASH,
                    metaAction.nonce,
                    metaAction.from,
                    hashAction(metaAction.actions)
                )
            );
    }

    function hashActions(Action[] memory actions)
        internal
        pure
        returns (bytes32[] memory)
    {
        bytes32[] memory hashedActions = new bytes32[](actions.length);
        for (uint256 i = 0; i < actions.length; i++) {
            hashedActions[i] = hashAction(actions[i]);
        }
        return hashedActions;
    }

    function hashAction(Action memory action) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    ACTION_TYPEHASH,
                    action.actionName,
                    action.from,
                    action.to,
                    action.amount
                )
            );
    }

    function executeMetaAction(
        address userAddress,
        Action memory actions,
        string memory _username,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    ) public payable returns (bytes memory) {
        MetaAction memory metaAction =
            MetaAction({
                nonce: _nonces[userAddress],
                from: userAddress,
                actions: actions
            });
        require(
            verifyAction(userAddress, metaAction, sigR, sigS, sigV),
            "Signer and signature do not match"
        );
        _nonces[userAddress] = _nonces[userAddress].add(1);
        // Append userAddress at the end to extract it from calling context
        // Perform whatever function with the parameter
        // (bool success, bytes memory returnData) = address(this).call(abi.encodePacked(bytes4(keccak256("setLatestUsername(string memory _username)")), _username));
        // require(success, "Function call not successful");
        // return returnData;
    }

    // function executeMetaTransaction(
    //     address userAddress,
    //     Action memory actions,
    //     bytes32 r,
    //     bytes32 s,
    //     uint8 v
    // ) external payable returns (bool isValid) {
    //     // bytes4 selector = _getSelector(functionSignature);
    //     // require(selector != msg.sig, "can not have meta-meta-transactions");

    //     MetaTransaction memory metaTx =
    //         MetaTransaction({
    //             nonce: _nonces[userAddress],
    //             from: userAddress,
    //             actions: actions
    //         });

    //     require(
    //         _verify(userAddress, metaTx, r, s, v),
    //         "signer and signature don't match"
    //     );

    //     isValid = true;
    //     emit MetaTransactionVerified(isValid, r, s, v);
    // }

    function getNonce(address user) external view returns (uint256 nonce) {
        nonce = _nonces[user];
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

    function verifyAction(
        address user,
        MetaAction memory metaAction,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    ) internal view returns (bool) {
        address signer =
            ecrecover(
                _hashTypedDataV4(hashMetaAction(metaAction)),
                sigV,
                sigR,
                sigS
            );
        require(signer != address(0), "Invalid signature");
        return signer == user;
    }

    // function _verify(
    //     address user,
    //     MetaTransaction memory metaTx,
    //     bytes32 r,
    //     bytes32 s,
    //     uint8 v
    // ) internal view returns (bool) {
    //     require(metaTx.nonce == _nonces[user], "invalid nonce");

    //     address signer =
    //         ecrecover(_hashTypedDataV4(_hashMetaTransaction(metaTx)), v, r, s);

    //     require(signer != address(0), "invalid signature");

    //     return signer == user;
    // }

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

    // function _hashActions(Action[] memory actions)
    //     internal
    //     pure
    //     returns (bytes32[] memory)
    // {
    //     bytes32[] memory hashedActions = new bytes32[](actions.length);
    //     for (uint256 i = 0; i < actions.length; i++) {
    //         hashedActions[i] = _hashAction(actions[i]);
    //     }
    //     return hashedActions;
    // }

    function _hashAction(Action memory action) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    ACTION_TYPEHASH,
                    action.actionName,
                    action.from,
                    action.to,
                    action.amount
                )
            );
    }

    // function _hashMetaTransaction(MetaTransaction memory metaTx)
    //     internal
    //     pure
    //     returns (bytes32)
    // {
    //     return
    //         keccak256(
    //             abi.encode(
    //                 _META_TRANSACTION_TYPEHASH,
    //                 metaTx.nonce,
    //                 metaTx.from,
    //                 _hashAction(metaTx.actions)
    //             )
    //         );
    // }
}
