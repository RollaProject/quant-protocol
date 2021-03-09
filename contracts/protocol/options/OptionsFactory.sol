// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./QToken.sol";
import "./CollateralToken.sol";
import "./OptionsUtils.sol";
import "./AssetsRegistry.sol";
import "../QuantConfig.sol";

/// @title Factory contract for Quant options
/// @author Quant Finance
/// @notice Creates tokens for long (QToken) and short (CollateralToken) positions
/// @dev This contract follows the factory design pattern
contract OptionsFactory {
    using SafeMath for uint256;

    /// @notice array of all the created QTokens
    address[] public qTokens;

    QuantConfig public quantConfig;

    CollateralToken public collateralToken;

    mapping(uint256 => address) private _collateralTokenIdToQTokenAddress;

    /// @notice mapping that can be used to check if a QToken at a given address has already been created
    mapping(address => uint256) public qTokenAddressToCollateralTokenId;

    /// @notice emitted when the factory creates a new option
    event OptionCreated(
        address qTokenAddress,
        address creator,
        address indexed underlying,
        address indexed strike,
        address oracle,
        uint256 strikePrice,
        uint256 expiry,
        uint256 collateralTokenId,
        uint256 allOptionsLength,
        bool isCall
    );

    /// @notice Initializes a new options factory
    /// @param _quantConfig the address of the Quant system configuration contract
    /// @param _collateralToken address of the CollateralToken contract
    constructor(address _quantConfig, address _collateralToken) {
        quantConfig = QuantConfig(_quantConfig);
        collateralToken = CollateralToken(_collateralToken);
    }

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
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    ) external view returns (address) {
        return
            OptionsUtils.getTargetQTokenAddress(
                address(quantConfig),
                _underlyingAsset,
                _strikeAsset,
                _oracle,
                _strikePrice,
                _expiryTime,
                _isCall
            );
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
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint256 _strikePrice,
        uint256 _expiryTime,
        uint256 _collateralizedFrom,
        bool _isCall
    ) external view returns (uint256) {
        return
            OptionsUtils.getTargetCollateralTokenId(
                collateralToken,
                address(quantConfig),
                _underlyingAsset,
                _strikeAsset,
                _oracle,
                _strikePrice,
                _expiryTime,
                _collateralizedFrom,
                _isCall
            );
    }

    /// @notice Creates new options (QToken + CollateralToken)
    /// @dev The CREATE2 opcode is used to deterministically deploy new QTokens
    /// @param _underlyingAsset asset that the option references
    /// @param _strikeAsset asset that the strike is denominated in
    /// @param _oracle price oracle for the option underlying
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @return newQToken address of the created QToken
    /// @return newCollateralTokenId id of the created CollateralToken
    function createOption(
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    ) external returns (address newQToken, uint256 newCollateralTokenId) {
        require(
            _expiryTime > block.timestamp,
            "OptionsFactory: given expiry time is in the past"
        );

        newCollateralTokenId = OptionsUtils.getTargetCollateralTokenId(
            collateralToken,
            address(quantConfig),
            _underlyingAsset,
            _strikeAsset,
            _oracle,
            _strikePrice,
            _expiryTime,
            0,
            _isCall
        );

        require(
            _collateralTokenIdToQTokenAddress[newCollateralTokenId] ==
                address(0),
            "OptionsFactory: option already created"
        );
        require(
            _isCall || _strikePrice > 0,
            "OptionsFactory: strike for put can't be 0"
        );

        {
            string memory symbol;
            (, symbol, ) = AssetsRegistry(quantConfig.assetsRegistry())
                .assetProperties(_underlyingAsset);
            require(
                bytes(symbol).length != 0,
                "OptionsFactory: underlying is not in the assets registry"
            );
        }

        newQToken = address(
            new QToken{salt: OptionsUtils.SALT}(
                address(quantConfig),
                _underlyingAsset,
                _strikeAsset,
                _oracle,
                _strikePrice,
                _expiryTime,
                _isCall
            )
        );

        _collateralTokenIdToQTokenAddress[newCollateralTokenId] = newQToken;
        qTokens.push(newQToken);

        qTokenAddressToCollateralTokenId[newQToken] = newCollateralTokenId;

        emit OptionCreated(
            newQToken,
            msg.sender,
            _underlyingAsset,
            _strikeAsset,
            _oracle,
            _strikePrice,
            _expiryTime,
            newCollateralTokenId,
            qTokens.length,
            _isCall
        );

        collateralToken.createCollateralToken(newQToken, 0);
    }

    /// @notice get the CollateralToken id for an already created CollateralToken,
    /// if no QToken has been created with these parameters, it will return 0
    /// @param _underlyingAsset asset that the option references
    /// @param _strikeAsset asset that the strike is denominated in
    /// @param _oracle price oracle for the option underlying
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _collateralizedFrom initial spread collateral
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @return id of the requested CollateralToken
    function getCollateralToken(
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint256 _strikePrice,
        uint256 _expiryTime,
        uint256 _collateralizedFrom,
        bool _isCall
    ) public view returns (uint256) {
        address qToken =
            getQToken(
                _underlyingAsset,
                _strikeAsset,
                _oracle,
                _strikePrice,
                _expiryTime,
                _isCall
            );

        uint256 id =
            collateralToken.getCollateralTokenId(qToken, _collateralizedFrom);

        (address storedQToken, ) = collateralToken.idToInfo(id);
        return storedQToken != address(0) ? id : 0;
    }

    /// @notice get the QToken address for an already created QToken, if no QToken has been created
    /// with these parameters, it will return the zero address
    /// @param _underlyingAsset asset that the option references
    /// @param _strikeAsset asset that the strike is denominated in
    /// @param _oracle price oracle for the option underlying
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @return address of the requested QToken
    function getQToken(
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    ) public view returns (address) {
        uint256 collateralTokenId =
            OptionsUtils.getTargetCollateralTokenId(
                collateralToken,
                address(quantConfig),
                _underlyingAsset,
                _strikeAsset,
                _oracle,
                _strikePrice,
                _expiryTime,
                0,
                _isCall
            );

        return _collateralTokenIdToQTokenAddress[collateralTokenId];
    }

    /// @notice get the total number of options created by the factory
    /// @return length of the options array
    function getOptionsLength() external view returns (uint256) {
        return qTokens.length;
    }
}
