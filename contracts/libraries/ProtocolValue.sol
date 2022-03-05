// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.12;

library ProtocolValue {
    enum Type {
        Address,
        Uint256,
        Bool,
        Role
    }

    function encode(string memory _protocolValue)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_protocolValue));
    }
}
