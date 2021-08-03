// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/drafts/EIP712.sol";
import "../libraries/ReferralCodeValidator.sol";

/// @title A registry for managing users and their referrers
contract ReferralRegistry is EIP712 {
    using SafeMath for uint256;
    using ReferralCodeValidator for string;

    enum ReferralAction {CLAIM_CODE, REGISTER_BY_CODE, REGISTER_BY_REFERRER}

    bytes32 public constant DEFAULT_CODE = "0";

    uint256 public maxCodesPerUser;

    address public immutable defaultReferrer;

    /// @notice mapping to store codes and their owners
    mapping(bytes32 => address) public codeOwner;

    /// @notice mapping to store users and their referrers
    mapping(address => address) public userReferrer;

    /// @notice mapping to store users and their codes
    mapping(address => bytes32[]) public userCodes;

    // Signature nonce per address
    mapping(address => uint256) public nonces;

    bytes32 private constant _META_REFERRAL_ACTION_TYPEHASH =
        keccak256(
            "metaReferralAction(address user,uint256 action,bytes actionData,uint256 nonce,uint256 deadline)"
        );

    event NewUserRegistration(
        address indexed referred,
        address indexed referrer,
        bytes32 code
    );
    event CreatedReferralCode(address indexed user, bytes32 code);

    /// @param _defaultReferrer Default referrer address
    /// @param _maxCodesPerUser Maximum number of codes a single user can claim
    constructor(
        address _defaultReferrer,
        uint256 _maxCodesPerUser,
        string memory _name,
        string memory _version
    ) EIP712(_name, _version) {
        defaultReferrer = _defaultReferrer;
        maxCodesPerUser = _maxCodesPerUser;
        _createReferralCode(_defaultReferrer, DEFAULT_CODE);
    }

    /// @notice Allows a user to claim a custom referral code
    /// @param codeStr The code for the user to claim
    function claimReferralCode(string memory codeStr) external {
        _claimReferralCode(msg.sender, codeStr);
    }

    /// @notice Register to Quant using a referral code
    /// @param code The code for the user to sign up with
    function registerUserByReferralCode(bytes32 code) external {
        _registerUserByReferralCode(msg.sender, code);
    }

    /// @notice Register to Quant using a referrer's address
    /// @param referrer Address of the referrer
    function registerUserByReferrer(address referrer) external {
        _registerUserByReferrer(msg.sender, referrer);
    }

    function metaReferralAction(
        address user,
        ReferralAction action,
        bytes memory actionData,
        uint256 nonce,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // solhint-disable-next-line not-rely-on-time
        require(
            block.timestamp <= deadline,
            "ReferralRegistry: expired deadline"
        );

        require(nonce == nonces[user], "ReferralRegistry: invalid nonce");

        bytes32 structHash =
            keccak256(
                abi.encode(
                    _META_REFERRAL_ACTION_TYPEHASH,
                    user,
                    action,
                    keccak256(actionData),
                    nonce,
                    deadline
                )
            );

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ecrecover(hash, v, r, s);
        require(signer == user, "ReferralRegistry: invalid signature");

        nonces[user] = nonces[user].add(1);

        if (action == ReferralAction.CLAIM_CODE) {
            string memory codeStr = abi.decode(actionData, (string));
            _claimReferralCode(user, codeStr);
        } else if (action == ReferralAction.REGISTER_BY_CODE) {
            bytes32 code = abi.decode(actionData, (bytes32));
            _registerUserByReferralCode(user, code);
        } else if (action == ReferralAction.REGISTER_BY_REFERRER) {
            address referrer = abi.decode(actionData, (address));
            _registerUserByReferrer(user, referrer);
        }
    }

    /// @notice Check who a user is referred by
    /// @param user the user to get the referrer of
    function getReferrer(address user)
        external
        view
        returns (address referrer)
    {
        return
            userReferrer[user] != address(0)
                ? userReferrer[user]
                : defaultReferrer;
    }

    /// @notice Check if a code has been claimed by another user
    /// @param code the code to check
    /// @return true if the code has been claimed otherwise false
    function isCodeUsed(bytes32 code) public view returns (bool) {
        return codeOwner[code] != address(0);
    }

    /// @notice Add referral code to registry
    /// @param user The user which is claiming a code
    /// @param code The code for the user to claim
    function _createReferralCode(address user, bytes32 code) internal {
        codeOwner[code] = user;
        userCodes[user].push(code);
        emit CreatedReferralCode(user, code);
    }

    /// @notice Register a user in the system
    /// @param referrer Address of the referrer
    /// @param code Referral code used. Default code if no code used
    function _registerUser(
        address user,
        address referrer,
        bytes32 code
    ) internal {
        require(
            userReferrer[user] == address(0),
            "ReferralRegistry: cannot register twice"
        );
        require(referrer != user, "ReferralRegistry: cannot refer self");
        userReferrer[user] = referrer;
        emit NewUserRegistration(user, referrer, code);
    }

    function _claimReferralCode(address user, string memory codeStr) internal {
        bytes32 code = codeStr.validateCode();

        require(!isCodeUsed(code), "ReferralRegistry: code already exists");
        require(
            userCodes[user].length < maxCodesPerUser,
            "ReferralRegistry: user has claimed all their codes"
        );
        _createReferralCode(user, code);
    }

    function _registerUserByReferralCode(address user, bytes32 code) internal {
        address referrer = codeOwner[code];
        if (referrer == address(0)) {
            referrer = defaultReferrer;
        }
        _registerUser(user, referrer, code);
    }

    function _registerUserByReferrer(address user, address referrer) internal {
        _registerUser(user, referrer, "");
    }
}
