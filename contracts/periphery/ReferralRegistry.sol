// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "hardhat/console.sol";
import "../libraries/ReferralCodeValidator.sol";

/// @title A registry for managing users and their referrers
contract ReferralRegistry {
    using ReferralCodeValidator for string;

    bytes32 public constant DEFAULT_CODE = "0";

    uint256 public maxCodesPerUser;

    address public immutable defaultReferrer;

    /// @notice mapping to store codes and their owners
    mapping(bytes32 => address) public codeOwner;

    /// @notice mapping to store users and their referrers
    mapping(address => address) public userReferrer;

    /// @notice mapping to store users and their codes
    mapping(address => bytes32[]) public userCodes;

    event NewUserRegistration(
        address indexed referred,
        address indexed referrer,
        bytes32 code
    );
    event CreatedReferralCode(address indexed user, bytes32 code);

    /// @param _defaultReferrer Default referrer address
    /// @param _maxCodesPerUser Maximum number of codes a single user can claim
    constructor(address _defaultReferrer, uint256 _maxCodesPerUser) {
        defaultReferrer = _defaultReferrer;
        maxCodesPerUser = _maxCodesPerUser;
        _createReferralCode(_defaultReferrer, DEFAULT_CODE);
    }

    /// @notice Allows a user to claim a custom referral code
    /// @param codeStr The code for the user to claim
    function claimReferralCode(string memory codeStr) external {
        bytes32 code = codeStr.validateCode();

        require(!isCodeUsed(code), "ReferralRegistry: code already exists");
        require(
            userCodes[msg.sender].length < maxCodesPerUser,
            "ReferralRegistry: user has claimed all their codes"
        );
        _createReferralCode(msg.sender, code);
    }

    /// @notice Register to Quant using a referral code
    /// @param code The code for the user to sign up with
    function registerUserByReferralCode(bytes32 code) external {
        address referrer = codeOwner[code];
        if (referrer == address(0)) {
            referrer = defaultReferrer;
        }
        _registerUser(referrer, code);
    }

    /// @notice Register to Quant using a referrer's address
    /// @param referrer Address of the referrer
    function registerUserByReferrer(address referrer) external {
        _registerUser(referrer, "");
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
        userCodes[msg.sender].push(code);
        emit CreatedReferralCode(user, code);
    }

    /// @notice Register a user in the system
    /// @param referrer Address of the referrer
    /// @param code Referral code used. Default code if no code used
    function _registerUser(address referrer, bytes32 code) internal {
        require(
            userReferrer[msg.sender] == address(0),
            "ReferralRegistry: cannot register twice"
        );
        require(referrer != msg.sender, "ReferralRegistry: cannot refer self");
        userReferrer[msg.sender] = referrer;
        emit NewUserRegistration(msg.sender, referrer, code);
    }
}
