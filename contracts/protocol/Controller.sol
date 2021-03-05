// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./QuantConfig.sol";
import "./options/OptionsFactory.sol";
import "./options/QToken.sol";
import "./options/CollateralToken.sol";

contract Controller {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    OptionsFactory private immutable _optionsFactory;
    CollateralToken private immutable _collateralToken;

    event OptionsPositionMinted(address indexed account, uint256 optionsAmount);

    constructor(address optionsFactory_, address collateralToken_) {
        _optionsFactory = OptionsFactory(optionsFactory_);
        _collateralToken = CollateralToken(collateralToken_);
    }

    function mintOptionsPosition(address _qToken, uint256 _optionsAmount)
        external
    {
        require(
            _optionsFactory.qTokenCreated(_qToken),
            "Controller: Option needs to be created by the factory first"
        );

        QToken qToken = QToken(_qToken);

        require(
            qToken.expiryTime() > block.timestamp,
            "Controller: Cannot mint expired options"
        );

        uint256 amountToMint = _optionsAmount.mul(10**18);

        emit OptionsPositionMinted(msg.sender, amountToMint);

        // Get the collateral required to mint the given _optionsAmount
        uint256 collateralAmount;
        if (qToken.isCall()) {
            IERC20 underlying = IERC20(qToken.underlyingAsset());

            collateralAmount = _optionsAmount.mul(
                10**ERC20(address(underlying)).decimals()
            );

            underlying.safeTransferFrom(
                msg.sender,
                address(this),
                collateralAmount
            );
        } else {
            IERC20 strike = IERC20(qToken.strikeAsset());

            collateralAmount = _optionsAmount.mul(qToken.strikePrice());

            strike.safeTransferFrom(
                msg.sender,
                address(this),
                collateralAmount
            );
        }

        // Mint the options to the sender's address
        qToken.mint(msg.sender, amountToMint);
        uint256 collateralTokenId =
            _collateralToken.getCollateralTokenId(_qToken, 0);
        _collateralToken.mintCollateralToken(
            msg.sender,
            collateralTokenId,
            amountToMint
        );
    }
}
