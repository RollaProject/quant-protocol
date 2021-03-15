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

    event SpreadMinted(
        address indexed account,
        address indexed qTokenToMint,
        address indexed qTokenForCollateral,
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

    function mintSpread(
        address _qTokenToMint,
        address _qTokenForCollateral,
        uint256 _optionsAmount
    ) external validQToken(_qTokenToMint) validQToken(_qTokenForCollateral) {
        QToken qTokenToMint = QToken(_qTokenToMint);
        QToken qTokenForCollateral = QToken(_qTokenForCollateral);

        // Check that expiries match
        require(
            qTokenToMint.expiryTime() == qTokenForCollateral.expiryTime(),
            "Controller: Can't create spreads from options with different expiries"
        );

        // Check that the underlyings match
        require(
            qTokenToMint.underlyingAsset() ==
                qTokenForCollateral.underlyingAsset(),
            "Controller: Can't create spreads from options with different underlying assets"
        );

        emit SpreadMinted(
            msg.sender,
            _qTokenToMint,
            _qTokenForCollateral,
            _optionsAmount
        );

        (address collateral, uint256 collateralAmount) =
            getCollateralRequirement(
                _qTokenToMint,
                _qTokenForCollateral,
                _optionsAmount
            );

        qTokenForCollateral.burn(msg.sender, _optionsAmount);

        if (collateralAmount > 0) {
            IERC20(collateral).safeTransferFrom(
                msg.sender,
                address(this),
                collateralAmount
            );

            // Check if the corresponding CollateralToken has already been created
            // Create it if it hasn't
            uint256 collateralTokenId =
                optionsFactory.collateralToken().getCollateralTokenId(
                    _qTokenToMint,
                    collateralAmount
                );
            (, uint256 collateralizedFrom) =
                optionsFactory.collateralToken().idToInfo(collateralTokenId);
            if (collateralizedFrom == 0) {
                optionsFactory.collateralToken().createCollateralToken(
                    _qTokenToMint,
                    collateralAmount
                );
            }

            optionsFactory.collateralToken().mintCollateralToken(
                msg.sender,
                collateralTokenId,
                collateralAmount
            );
        }

        qTokenToMint.mint(msg.sender, _optionsAmount);
    }

    function getCollateralRequirement(
        address _qTokenToMint,
        address _qTokenForCollateral,
        uint256 _optionsAmount
    ) public view returns (address collateral, uint256 collateralAmount) {
        QToken qTokenToMint = QToken(_qTokenToMint);
        uint256 qTokenToMintStrikePrice = qTokenToMint.strikePrice();

        uint256 qTokenForCollateralStrikePrice;
        if (_qTokenForCollateral != address(0)) {
            QToken qTokenForCollateral = QToken(_qTokenForCollateral);
            qTokenForCollateralStrikePrice = qTokenForCollateral.strikePrice();
        }

        uint256 collateralPerOption;
        address underlying;
        if (qTokenToMint.isCall()) {
            underlying = qTokenToMint.underlyingAsset();

            // Initially required collateral is the long strike price
            (, , uint8 underlyingDecimals) =
                AssetsRegistry(optionsFactory.quantConfig().assetsRegistry())
                    .assetProperties(underlying);

            collateralPerOption = 10**underlyingDecimals;

            if (_qTokenForCollateral != address(0)) {
                collateralPerOption = qTokenToMintStrikePrice >
                    qTokenForCollateralStrikePrice
                    ? 0 // Call Debit Spread
                    : _absSub(
                        qTokenForCollateralStrikePrice,
                        qTokenToMintStrikePrice
                    )
                        .mul(10**18)
                        .div(qTokenForCollateralStrikePrice); // Call Credit Spread
            }
        } else {
            // Initially required collateral is the long strike price
            collateralPerOption = qTokenToMintStrikePrice;

            if (_qTokenForCollateral != address(0)) {
                collateralPerOption = qTokenToMintStrikePrice >
                    qTokenForCollateralStrikePrice
                    ? qTokenToMintStrikePrice.sub(
                        qTokenForCollateralStrikePrice
                    ) // Put Credit Spread
                    : 0; // Put Debit Spread
            }
        }

        collateralAmount = _optionsAmount.mul(collateralPerOption).div(
            10**OPTIONS_DECIMALS
        );

        return (
            qTokenToMint.isCall() ? underlying : qTokenToMint.strikeAsset(),
            collateralAmount
        );
    }

    function _absSub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a.sub(b) : b.sub(a);
    }
}
