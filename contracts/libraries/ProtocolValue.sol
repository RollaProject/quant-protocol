// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

library ProtocolValue {
    function encode(string memory _protocolValue)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_protocolValue));
    }
}
