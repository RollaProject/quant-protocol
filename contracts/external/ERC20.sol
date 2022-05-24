// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.14;

import {Clone} from "@rolla-finance/clones-with-immutable-args/Clone.sol";
import "../utils/CustomErrors.sol";

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author zefram.eth (https://github.com/ZeframLou/vested-erc20/blob/main/src/lib/ERC20.sol)
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
/// @dev Modified by Rolla to include name and symbol represented as uint256 arrays with 4 elements (128 bytes).
/// @dev The original ERC20 implementation with Clone from clones-with-immutable-args written by zefram.eth included
/// name and symbol with 32 bytes each, which would not be enough for Quant's QToken possibly long names and symbols.
abstract contract ERC20 is Clone {
    /*///////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );

    /*///////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint256) public nonces;

    /*///////////////////////////////////////////////////////////////
                               METADATA
    //////////////////////////////////////////////////////////////*/

    function name() external view returns (string memory nameStr) {
        nameStr = _get128BytesStringArg(0);
    }

    function symbol() external view returns (string memory symbolStr) {
        symbolStr = _get128BytesStringArg(0x80);
    }

    function decimals() external pure returns (uint8) {
        return _getArgUint8(0x100);
    }

    /*///////////////////////////////////////////////////////////////
                              ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount)
        public
        virtual
        returns (bool)
    {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount)
        public
        virtual
        returns (bool)
    {
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max)
            allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(
                recoveredAddress != address(0) && recoveredAddress == owner,
                "INVALID_SIGNER"
            );

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        bytes32 nameHash = keccak256(bytes(_get128BytesStringArg(0)));

        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    nameHash,
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /*///////////////////////////////////////////////////////////////
                       INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }

    /// @notice Read a 128 bytes string stored as a uint256 array in the immutable args,
    /// where the last byte is the length of the string.
    /// @param stringArgOffset The offset of the string immutable arg in the packed data
    /// @return stringArg The string immutable arg, in memory
    function _get128BytesStringArg(uint256 stringArgOffset)
        private
        view
        returns (string memory stringArg)
    {
        uint256[] memory stringArgBytes32Array = _getArgUint256Array(
            stringArgOffset,
            4 // array of uint256 with 4 elements (128 bytes)
        );

        assembly ("memory-safe") {
            // read the length of the string, which should be stored as the 128th byte
            // in the array
            let strLength := shr(0xf8, mload(add(stringArgBytes32Array, 0x80)))

            // allocate memory for the output string
            stringArg := mload(0x40)
            // update the free memory pointer, padding the string length
            // (which is stored before the string contents) to 32 bytes
            mstore(
                0x40,
                add(stringArg, and(add(add(strLength, 0x20), 0x1f), not(0x1f)))
            )
            // store the string length in memory
            mstore(stringArg, strLength)

            // use the identity precompile to copy the bytes in memory
            // from the uint256 array to the output string
            if iszero(
                staticcall(
                    gas(),
                    0x04,
                    add(stringArgBytes32Array, 0x20),
                    strLength,
                    add(stringArg, 0x20),
                    strLength
                )
            ) {
                mstore(
                    IdentityPrecompileFailure_error_sig_ptr,
                    IdentityPrecompileFailure_error_signature
                )
                revert(
                    IdentityPrecompileFailure_error_sig_ptr,
                    IdentityPrecompileFailure_error_length
                )
            }
        }
    }
}
