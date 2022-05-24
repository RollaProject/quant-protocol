// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.14;

// abi.encodeWithSignature("IdentityPrecompileFailure()")
uint256 constant IdentityPrecompileFailure_error_signature = (
    0x3a008ffa00000000000000000000000000000000000000000000000000000000
);

uint256 constant IdentityPrecompileFailure_error_sig_ptr = 0x0;

uint256 constant IdentityPrecompileFailure_error_length = 0x4;

// abi.encodeWithSignature("DataSizeLimitExceeded(uint256)");
uint256 constant DataSizeLimitExceeded_error_signature = (
    0x5307a82000000000000000000000000000000000000000000000000000000000
);

uint256 constant DataSizeLimitExceeded_error_sig_ptr = 0x0;

uint256 constant DataSizeLimitExceeded_error_datasize_ptr = 0x4;

uint256 constant DataSizeLimitExceeded_error_length = 0x24; // 4 + 32 == 36
