// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../QuantConfig.sol";

contract CollateralToken is ERC1155 {
    /// @dev stores metadata for a CollateralToken with an specific id
    /// @param underlyingAsset asset that the option references
    /// @param strikeAsset asset that the strike is denominated in
    /// @param oracle price oracle for the option underlying
    /// @param strikePrice strike price with as many decimals in the strike asset
    /// @param expiryTime expiration timestamp as a unix timestamp
    /// @param collateralizedFrom initial spread collateral
    /// @param isCall true if it's a call option, false if it's a put option
    struct CollateralTokenInfo {
        address underlyingAsset;
        address strikeAsset;
        address oracle;
        uint256 strikePrice;
        uint256 expiryTime;
        uint256 collateralizedFrom;
        bool isCall;
    }

    /// @dev The Quant system config
    QuantConfig public quantConfig;

    /// @dev mapping of CollateralToken ids to their respective info struct
    mapping(uint256 => CollateralTokenInfo) private _idToInfo;

    /// @notice array of all the created CollateralToken ids
    uint256[] public collateralTokensIds;

    /// @notice Initializes a new ERC1155 multi-token contract for representing
    /// users' short positions
    /// @param _quantConfig the address of the Quant system configuration contract
    constructor(address _quantConfig) ERC1155("URI") {
        quantConfig = QuantConfig(_quantConfig);
    }

    /// @notice Create new CollateralTokens
    /// @dev Should also be used elsewhere where getting a CollateralToken id from
    /// its parameters is necessary
    /// @param _underlyingAsset asset that the option references
    /// @param _strikeAsset asset that the strike is denominated in
    /// @param _oracle price oracle for the option underlying
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _collateralizedFrom initial spread collateral
    /// @param _isCall true if it's a call option, false if it's a put option
    /// @return id the id for the CollateralToken with the given arguments
    function createCollateralToken(
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint256 _strikePrice,
        uint256 _expiryTime,
        uint256 _collateralizedFrom,
        bool _isCall
    ) external returns (uint256 id) {
        id = uint256(
            keccak256(
                abi.encodePacked(
                    _underlyingAsset,
                    _strikeAsset,
                    _oracle,
                    _strikePrice,
                    _expiryTime,
                    _collateralizedFrom,
                    _isCall
                )
            )
        );

        if (
            // The function caller has permission to create new CollateralTokens
            quantConfig.hasRole(
                quantConfig.OPTIONS_CONTROLLER_ROLE(),
                msg.sender
            ) && _idToInfo[id].underlyingAsset != address(0)
            // The CollateralToken with this id has not been created yet
        ) {
            _idToInfo[id] = CollateralTokenInfo({
                underlyingAsset: _underlyingAsset,
                strikeAsset: _strikeAsset,
                oracle: _oracle,
                strikePrice: _strikePrice,
                expiryTime: _expiryTime,
                collateralizedFrom: _collateralizedFrom,
                isCall: _isCall
            });

            collateralTokensIds.push(id);
        }
    }

    /// @notice Mint CollateralTokens for a given account
    /// @param recipient address to receive the minted tokens
    /// @param amount amount of tokens to mint
    /// @param collateralTokenId id of the token to be minted
    function mintCollateralToken(
        address recipient,
        uint256 amount,
        uint256 collateralTokenId
    ) external {
        require(
            quantConfig.hasRole(
                quantConfig.OPTIONS_CONTROLLER_ROLE(),
                msg.sender
            ),
            "CollateralToken: Only the OptionsFactory can mint CollateralTokens"
        );
        _mint(recipient, amount, collateralTokenId, "");
    }

    /// @notice Mint CollateralTokens for a given account
    /// @param owner address to burn tokens from
    /// @param amount amount of tokens to burn
    /// @param collateralTokenId id of the token to be burned
    function burnCollateralToken(
        address owner,
        uint256 amount,
        uint256 collateralTokenId
    ) external {
        require(
            quantConfig.hasRole(
                quantConfig.OPTIONS_CONTROLLER_ROLE(),
                msg.sender
            ),
            "CollateralToken: Only the OptionsFactory can burn CollateralTokens"
        );
        _burn(owner, collateralTokenId, amount);
    }
}
