// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/utils/Create2.sol";
import "./QToken.sol";
import "./CollateralToken.sol";

library OptionsUtils {
    /// @dev constant salt because options will only be deployed with the same parameters once
    bytes32 public constant SALT = bytes32(0);

    /// @notice get the address at which a new QToken with the given parameters would be deployed
    /// @notice return the exact address the QToken will be deployed at with OpenZeppelin's Create2
    /// library computeAddress function
    /// @param _underlyingAsset asset that the option references
    /// @param _strikeAsset asset that the strike is denominated in
    /// @param _oracle price oracle for the option underlying
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @return the address where a QToken would be deployed
    function getTargetQTokenAddress(
        address _quantConfig,
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    ) internal view returns (address) {
        bytes32 bytecodeHash =
            keccak256(
                abi.encodePacked(
                    type(QToken).creationCode,
                    abi.encode(
                        _quantConfig,
                        _underlyingAsset,
                        _strikeAsset,
                        _oracle,
                        _strikePrice,
                        _expiryTime,
                        _isCall
                    )
                )
            );

        return Create2.computeAddress(SALT, bytecodeHash);
    }

    /// @notice get the id that a CollateralToken with the given parameters would have
    /// @param _underlyingAsset asset that the option references
    /// @param _strikeAsset asset that the strike is denominated in
    /// @param _oracle price oracle for the option underlying
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _collateralizedFrom initial spread collateral
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @return the id that a CollateralToken would have
    function getTargetCollateralTokenId(
        CollateralToken _collateralToken,
        address _quantConfig,
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint256 _strikePrice,
        uint256 _expiryTime,
        uint256 _collateralizedFrom,
        bool _isCall
    ) internal view returns (uint256) {
        address qToken =
            OptionsUtils.getTargetQTokenAddress(
                _quantConfig,
                _underlyingAsset,
                _strikeAsset,
                _oracle,
                _strikePrice,
                _expiryTime,
                _isCall
            );
        return
            _collateralToken.getCollateralTokenId(qToken, _collateralizedFrom);
    }

    /// @notice Returns a unique option hash based on its parameters
    /// @param _underlyingAsset asset that the option references
    /// @param _strikeAsset asset that the strike is denominated in
    /// @param _oracle price oracle for the option underlying
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @return 32-bytes hash unique to an option
    function qTokenHash(
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _underlyingAsset,
                    _strikeAsset,
                    _oracle,
                    _strikePrice,
                    _expiryTime,
                    _isCall
                )
            );
    }
}
