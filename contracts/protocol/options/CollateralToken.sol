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
    /// @param _underlyingAsset asset that the option references
    /// @param _strikeAsset asset that the strike is denominated in
    /// @param _oracle price oracle for the option underlying
    /// @param _strikePrice strike price with as many decimals in the strike asset
    /// @param _expiryTime expiration timestamp as a unix timestamp
    /// @param _collateralizedFrom initial spread collateral
    /// @param _isCall true if it's a call option, false if it's a put option
    function createCollateralToken(
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint256 _strikePrice,
        uint256 _expiryTime,
        uint256 _collateralizedFrom,
        bool _isCall
    ) external {
        uint256 id =
            uint256(
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

    function mintCollateralToken(
        address recipient,
        uint256 amount,
        bytes32 collateralTokenHash
    ) external {
        require(
            quantConfig.hasRole(
                quantConfig.OPTIONS_CONTROLLER_ROLE(),
                msg.sender
            ),
            "CollateralToken: Only the OptionsFactory can mint CollateralTokens"
        );
        _mint(recipient, amount, uint256(collateralTokenHash), "");
    }

    function burnCollateralToken(
        address owner,
        uint256 amount,
        bytes32 collateralTokenHash
    ) external {
        require(
            quantConfig.hasRole(
                quantConfig.OPTIONS_CONTROLLER_ROLE(),
                msg.sender
            ),
            "CollateralToken: Only the OptionsFactory can mint CollateralTokens"
        );
        _burn(owner, uint256(collateralTokenHash), amount);
    }
}
