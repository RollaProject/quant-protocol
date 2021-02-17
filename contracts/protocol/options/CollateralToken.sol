// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../QuantConfig.sol";

contract CollateralToken is ERC1155 {
    struct CollateralTokenInfo {
        address underlyingAsset;
        address strikeAsset;
        address oracle;
        uint256 strikePrice;
        uint256 expiryTime;
        uint256 collateralizedFrom;
        bool isCall;
    }

    QuantConfig public quantConfig;

    mapping(bytes32 => CollateralTokenInfo) public collateralTokens;

    constructor(address _quantConfig) ERC1155("URI") {
        quantConfig = QuantConfig(_quantConfig);
    }

    function createCollateralToken(
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint256 _strikePrice,
        uint256 _expiryTime,
        uint256 _collateralizedFrom,
        bool _isCall
    ) external {
        bytes32 collateralTokenHash =
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
            );
        collateralTokens[collateralTokenHash] = CollateralTokenInfo({
            underlyingAsset: _underlyingAsset,
            strikeAsset: _strikeAsset,
            oracle: _oracle,
            strikePrice: _strikePrice,
            expiryTime: _expiryTime,
            collateralizedFrom: _collateralizedFrom,
            isCall: _isCall
        });
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
