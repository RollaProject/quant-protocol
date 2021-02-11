// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "./QToken.sol";
import "../QuantConfig.sol";

contract OptionsFactory {
    using SafeMath for uint256;

    /// @notice array of all the created options
    address[] public options;

    QuantConfig private _quantConfig;

    /// @dev constant salt because options will only be deployed with the same parameters once
    bytes32 private constant _SALT = bytes32(0);

    mapping(bytes32 => address) private _hashToAddress;

    /// @notice emitted when the factory creates a new option
    event OptionCreated(
        address optionTokenAddress,
        address creator,
        address indexed underlying,
        address indexed strike,
        address oracle,
        uint256 strikePrice,
        uint256 expiry,
        bool isCall
    );

    /// @notice Initializes a new options factory
    /// @param quantConfig_ the address of the Quant system configuration contract
    constructor(address quantConfig_) {
        _quantConfig = QuantConfig(quantConfig_);
    }

    /// @notice Creates new QTokens
    /// @dev The CREATE2 opcode is used to deterministically deploy new QTokens
    /// @param _underlyingAsset asset that the option references
    /// @param _strikeAsset asset that the strike is denominated in
    /// @param _oracle price oracle for the option underlying
    /// @param _strikePrice strike price with 18 decimals
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @return address of the created option
    function createOption(
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    ) external returns (address) {
        require(
            _expiryTime > block.timestamp,
            "OptionsFactory: given expiry time is in the past"
        );
        bytes32 optionHash =
            _optionHash(
                _underlyingAsset,
                _strikeAsset,
                _oracle,
                _strikePrice,
                _expiryTime,
                _isCall
            );
        require(
            _hashToAddress[optionHash] == address(0),
            "OptionsFactory: option already creted"
        );
        require(
            _isCall || _strikePrice > 0,
            "OptionsFactory: strike for put can't be 0"
        );

        bytes memory bytecode =
            abi.encodePacked(
                type(QToken).creationCode,
                abi.encode(
                    address(_quantConfig),
                    _underlyingAsset,
                    _strikeAsset,
                    _strikePrice,
                    _expiryTime,
                    _isCall
                )
            );

        address newOption = Create2.deploy(0, _SALT, bytecode);

        _hashToAddress[optionHash] = newOption;
        options.push(newOption);

        emit OptionCreated(
            newOption,
            msg.sender,
            _underlyingAsset,
            _strikeAsset,
            _oracle,
            _strikePrice,
            _expiryTime,
            _isCall
        );

        return newOption;
    }

    /// @notice get the address at which a new QToken with the given parameters would be deployed
    /// @notice return the exact address the QToken will be deployed at with OpenZeppelin's Create2
    /// library computeAddress function
    /// @param _underlyingAsset asset that the option references
    /// @param _strikeAsset asset that the strike is denominated in
    /// @param _oracle price oracle for the option underlying
    /// @param _strikePrice strike price with 18 decimals
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @return the address where a QToken would be deployed
    function getTargetQTokenAddress(
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    ) external view returns (address) {
        bytes32 bytecodeHash =
            keccak256(
                abi.encodePacked(
                    type(QToken).creationCode,
                    abi.encode(
                        address(_quantConfig),
                        _underlyingAsset,
                        _strikeAsset,
                        _oracle,
                        _strikePrice,
                        _expiryTime,
                        _isCall
                    )
                )
            );

        return Create2.computeAddress(_SALT, bytecodeHash);
    }

    /// @notice get the QToken address for an already created QToken, if no QToken has been created
    /// with these parameters, it will return the zero address
    /// @param _underlyingAsset asset that the option references
    /// @param _strikeAsset asset that the strike is denominated in
    /// @param _oracle price oracle for the option underlying
    /// @param _strikePrice strike price with 18 decimals
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @return address of the requested option
    function getQToken(
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    ) external view returns (address) {
        bytes32 optionHash =
            _optionHash(
                _underlyingAsset,
                _strikeAsset,
                _oracle,
                _strikePrice,
                _expiryTime,
                _isCall
            );

        return _hashToAddress[optionHash];
    }

    /// @notice get the total number of options created by the factory
    /// @return length of the options array
    function getOptionsLength() external view returns (uint256) {
        return options.length;
    }

    /// @notice Returns a unique option hash based on its parameters
    /// @param _underlyingAsset asset that the option references
    /// @param _strikeAsset asset that the strike is denominated in
    /// @param _oracle price oracle for the option underlying
    /// @param _strikePrice strike price with 18 decimals
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @return 32-bytes hash unique to an option
    function _optionHash(
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
