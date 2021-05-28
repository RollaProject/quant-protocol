// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/drafts/EIP712Upgradeable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IEIP712MetaTransaction.sol";
import "./interfaces/IController.sol";
import "./libraries/Actions.sol";
import {ActionArgs} from "./libraries/Actions.sol";

contract EIP712MetaTransaction is EIP712Upgradeable {
    using SafeMath for uint256;

    struct MetaAction {
        uint256 nonce;
        address from;
        ActionArgs[] actions;
    }

    // bytes32 private constant EIP712_DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant _META_ACTION_TYPEHASH =
        keccak256(
            "MetaAction(uint256 nonce,address from,ActionArgs[] actions)ActionArgs(string actionType,address qToken,address secondaryAddress,address receiver,uint256 amount,uint256 collateralTokenId,bytes data)"
        );
    bytes32 private constant _ACTION_TYPEHASH =
        keccak256(
            "ActionArgs(string actionType,address qToken,address secondaryAddress,address receiver,uint256 amount,uint256 collateralTokenId,bytes data)"
        );

    mapping(address => uint256) private _nonces;

    event MetaTransactionExecuted(
        address indexed userAddress,
        address payable indexed relayerAddress,
        uint256 nonce
    );

    function hashActions(ActionArgs[] memory actions)
        private
        pure
        returns (bytes32[] memory)
    {
        bytes32[] memory hashedActions = new bytes32[](actions.length);
        for (uint256 i = 0; i < actions.length; i++) {
            hashedActions[i] = hashAction(actions[i]);
        }
        return hashedActions;
    }

    // functions to generate hash representation of the struct objects
    function hashAction(ActionArgs memory action)
        private
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    _ACTION_TYPEHASH,
                    keccak256(bytes(action.actionType)),
                    action.qToken,
                    action.secondaryAddress,
                    action.receiver,
                    action.amount,
                    action.collateralTokenId,
                    keccak256(action.data)
                )
            );
    }

    function hashMetaAction(MetaAction memory metaAction)
        private
        view
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    _META_ACTION_TYPEHASH,
                    metaAction.nonce,
                    metaAction.from,
                    keccak256(abi.encodePacked(hashActions(metaAction.actions)))
                )
            );
    }

    function executeMetaTransaction(
        address userAddress,
        ActionArgs[] memory actions,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external payable returns (bytes memory) {
        MetaAction memory metaAction =
            MetaAction({
                nonce: _nonces[userAddress],
                from: userAddress,
                actions: actions
            });

        require(
            _verify(userAddress, metaAction, r, s, v),
            "signer and signature don't match"
        );

        _nonces[userAddress] = _nonces[userAddress].add(1);

        // Append the userAddress at the end so that it can be extracted later
        // from the calling context (see _msgSender() below)
        (bool success, bytes memory returnData) =
            address(this).call(
                abi.encodePacked(
                    abi.encodeWithSelector(
                        IController(address(this)).operate.selector,
                        actions
                    ),
                    userAddress
                )
            );

        require(success, "unsuccessful function call");
        emit MetaTransactionExecuted(
            userAddress,
            msg.sender,
            _nonces[userAddress]
        );
        return returnData;
    }

    function getNonce(address user) external view returns (uint256 nonce) {
        nonce = _nonces[user];
    }

    function initializeEIP712(string memory name, string memory version)
        public
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

    function toAsciiString(address x) public view returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(x)) / (2**(8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(s);
    }

    function char(bytes1 b) internal view returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    function _verify(
        address user,
        MetaAction memory metaAction,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) internal view returns (bool) {
        require(metaAction.nonce == _nonces[user], "invalid nonce");

        address signer =
            ecrecover(_hashTypedDataV4(hashMetaAction(metaAction)), v, r, s);

        require(signer != address(0), "invalid signature");

        // revert(toAsciiString(signer));

        return signer == user;
    }
}
