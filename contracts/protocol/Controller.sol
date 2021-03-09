// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./QuantConfig.sol";
import "./options/OptionsFactory.sol";
import "./options/QToken.sol";
import "./options/CollateralToken.sol";
import "./options/AssetsRegistry.sol";

import "hardhat/console.sol";

contract Controller {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    OptionsFactory public immutable optionsFactory;

    uint8 public constant OPTIONS_DECIMALS = 18;

    event OptionsPositionMinted(
        address indexed account,
        address indexed qToken,
        uint256 optionsAmount
    );

    constructor(address _optionsFactory) {
        optionsFactory = OptionsFactory(_optionsFactory);
    }

    modifier validQToken(address _qToken) {
        require(
            optionsFactory.qTokenAddressToCollateralTokenId(_qToken) != 0,
            "Controller: Option needs to be created by the factory first"
        );

        QToken qToken = QToken(_qToken);

        require(
            qToken.expiryTime() > block.timestamp,
            "Controller: Cannot mint expired options"
        );

        _;
    }

    function mintOptionsPosition(address _qToken, uint256 _optionsAmount)
        external
        validQToken(_qToken)
    {
        QToken qToken = QToken(_qToken);

        emit OptionsPositionMinted(msg.sender, _qToken, _optionsAmount);

        (address collateral, uint256 collateralAmount) =
            getCollateralRequirement(_qToken, address(0), _optionsAmount);

        IERC20(collateral).safeTransferFrom(
            msg.sender,
            address(this),
            collateralAmount
        );

        // Mint the options to the sender's address
        qToken.mint(msg.sender, _optionsAmount);
        uint256 collateralTokenId =
            optionsFactory.collateralToken().getCollateralTokenId(_qToken, 0);
        optionsFactory.collateralToken().mintCollateralToken(
            msg.sender,
            collateralTokenId,
            _optionsAmount
        );
    }

    function mintSpread(address _qTokenShort, address _qTokenLong)
        external
        // uint256 _optionsAmount
        validQToken(_qTokenShort)
        validQToken(_qTokenLong)
    {
        QToken qTokenShort = QToken(_qTokenShort);
        QToken qTokenLong = QToken(_qTokenLong);

        // Check that expiries match
        require(
            qTokenShort.expiryTime() == qTokenLong.expiryTime(),
            "Controller: Can't create spreads from options with different expiries"
        );

        // Check that the underlyings match
        require(
            qTokenShort.underlyingAsset() == qTokenLong.underlyingAsset(),
            "Controller: Can't create spreads from options with different underlying assets"
        );

        // (address collateral, uint256 collateralAmount) =
        //     getCollateralRequirement(_qTokenShort, _qTokenLong, _optionsAmount);
    }

    function getCollateralRequirement(
        address _qTokenShort,
        address _qTokenLong,
        uint256 _optionsAmount
    ) public view returns (address collateral, uint256 collateralAmount) {
        QToken qTokenShort = QToken(_qTokenShort);

        if (qTokenShort.isCall()) {
            address underlying = qTokenShort.underlyingAsset();

            collateralAmount = _optionsAmount.mul(
                (10**ERC20(underlying).decimals()).div(10**OPTIONS_DECIMALS)
            );

            return (underlying, collateralAmount);
        } else {
            uint256 qTokenShortStrikePrice = qTokenShort.strikePrice();

            // Initially required collateral is the long strike price
            uint256 collateralPerOption = qTokenShortStrikePrice;

            if (_qTokenLong != address(0)) {
                QToken qTokenLong = QToken(_qTokenLong);
                uint256 qTokenLongStrikePrice = qTokenLong.strikePrice();
                collateralPerOption = qTokenShortStrikePrice >
                    qTokenLongStrikePrice
                    ? qTokenShortStrikePrice.sub(qTokenLongStrikePrice) // PUT Credit Spread
                    : 0; // Put Debit Spread
            }

            collateralAmount = _optionsAmount.mul(collateralPerOption).div(
                10**OPTIONS_DECIMALS
            );

            return (qTokenShort.strikeAsset(), collateralAmount);
        }
    }
}
