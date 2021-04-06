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

    event OptionsExercised(
        address indexed account,
        address indexed qToken,
        uint256 amountExercised,
        uint256 payout,
        address payoutAsset
    );

    event NeutralizePosition(
        address indexed account,
        address qToken,
        uint256 amountNeutralized,
        uint256 collateralReclaimed,
        address collateralAsset,
        address longTokenReturned
    );

    event CollateralClaimed(
        address indexed account,
        uint256 indexed collateralTokenId,
        uint256 amountClaimed,
        uint256 collateralReturned,
        address collateralAsset
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
            optionsFactory.collateralToken().getCollateralTokenId(
                _qToken,
                address(0)
            );
        optionsFactory.collateralToken().mintCollateralToken(
            msg.sender,
            collateralTokenId,
            _optionsAmount
        );

        emit OptionsPositionMinted(msg.sender, _qToken, _optionsAmount);
    }

    function mintSpread(
        address _qTokenToMint,
        address _qTokenForCollateral,
        uint256 _optionsAmount
    ) external validQToken(_qTokenToMint) validQToken(_qTokenForCollateral) {
        QToken qTokenToMint = QToken(_qTokenToMint);
        QToken qTokenForCollateral = QToken(_qTokenForCollateral);

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
        }

        // Check if the corresponding CollateralToken has already been created
        // Create it if it hasn't
        uint256 collateralTokenId =
            optionsFactory.collateralToken().getCollateralTokenId(
                _qTokenToMint,
                _qTokenForCollateral
            );
        (, address qTokenAsCollateral) =
            optionsFactory.collateralToken().idToInfo(collateralTokenId);
        if (qTokenAsCollateral == address(0)) {
            optionsFactory.collateralToken().createCollateralToken(
                _qTokenToMint,
                _qTokenForCollateral
            );
        }

        optionsFactory.collateralToken().mintCollateralToken(
            msg.sender,
            collateralTokenId,
            _optionsAmount
        );

        qTokenToMint.mint(msg.sender, _optionsAmount);

        emit SpreadMinted(
            msg.sender,
            _qTokenToMint,
            _qTokenForCollateral,
            _optionsAmount
        );
    }

    function exercise(address _qToken, uint256 _amount) external {
        QToken qToken = QToken(_qToken);
        require(
            block.timestamp > qToken.expiryTime(),
            "Controller: Can not exercise options before their expiry"
        );

        uint256 amountToExercise;
        if (_amount == 0) {
            amountToExercise = qToken.balanceOf(msg.sender);
        } else {
            amountToExercise = _amount;
        }

        (bool isSettled, address payoutToken, uint256 payoutAmount) =
            getPayout(_qToken, amountToExercise);
        require(isSettled, "Controller: Cannot exercise unsettled options");

        qToken.burn(msg.sender, amountToExercise);

        if (payoutAmount > 0) {
            IERC20(payoutToken).transfer(msg.sender, payoutAmount);
        }

        emit OptionsExercised(
            msg.sender,
            _qToken,
            amountToExercise,
            payoutAmount,
            payoutToken
        );
    }

    function claimCollateral(uint256 _collateralTokenId, uint256 _amount)
        external
    {
        (address _qTokenShort, address qTokenAsCollateral) =
            optionsFactory.collateralToken().idToInfo(_collateralTokenId);

        require(
            _qTokenShort != address(0),
            "Controller: Can not claim collateral from non-existing option"
        );

        QToken qTokenShort = QToken(_qTokenShort);

        require(
            block.timestamp > qTokenShort.expiryTime(),
            "Controller: Can not claim collateral from options before their expiry"
        );
        require(
            qTokenShort.getOptionPriceStatus() == PriceStatus.SETTLED,
            "Controller: Can not claim collateral before option is settled"
        );

        uint256 amountToClaim =
            _amount == 0
                ? optionsFactory.collateralToken().balanceOf(
                    msg.sender,
                    _collateralTokenId
                )
                : _amount;

        address qTokenLong;
        uint256 payoutFromLong;
        if (qTokenAsCollateral != address(0)) {
            qTokenLong = qTokenAsCollateral;

            (, , payoutFromLong) = getPayout(qTokenLong, amountToClaim);
        } else {
            qTokenLong = address(0);
            payoutFromLong = 0;
        }

        (address collateralAsset, uint256 collateralRequirement) =
            getCollateralRequirement(_qTokenShort, qTokenLong, amountToClaim);

        (, , uint256 payoutFromShort) = getPayout(_qTokenShort, amountToClaim);

        uint256 returnableCollateral =
            payoutFromLong.add(collateralRequirement).sub(payoutFromShort);

        optionsFactory.collateralToken().burnCollateralToken(
            msg.sender,
            _collateralTokenId,
            amountToClaim
        );

        if (returnableCollateral > 0) {
            IERC20(collateralAsset).safeTransfer(
                msg.sender,
                returnableCollateral
            );
        }

        emit CollateralClaimed(
            msg.sender,
            _collateralTokenId,
            amountToClaim,
            returnableCollateral,
            collateralAsset
        );
    }

    function neutralizePosition(uint256 _collateralTokenId, uint256 _amount)
        external
    {
        CollateralToken collateralToken = optionsFactory.collateralToken();
        (address qTokenShort, address qTokenAsCollateral) =
            collateralToken.idToInfo(_collateralTokenId);

        //get the amount of collateral tokens owned
        uint256 collateralTokensOwned =
            collateralToken.balanceOf(msg.sender, _collateralTokenId);

        //get the amount of qTokens owned
        uint256 qTokensOwned = QToken(qTokenShort).balanceOf(msg.sender);

        //the amount of position that can be neutralized
        uint256 maxNeutralizable =
            qTokensOwned > collateralTokensOwned
                ? qTokensOwned
                : collateralTokensOwned;

        uint256 amountToNeutralize;

        if (_amount != 0) {
            require(
                _amount <= maxNeutralizable,
                "Controller: Tried to neutralize more than balance"
            );
            amountToNeutralize = _amount;
        } else {
            amountToNeutralize = maxNeutralizable;
        }

        (address collateralType, uint256 collateralOwed) =
            getCollateralRequirement(
                qTokenShort,
                address(0),
                amountToNeutralize
            );

        QToken(qTokenShort).burn(msg.sender, amountToNeutralize);

        collateralToken.burnCollateralToken(
            msg.sender,
            _collateralTokenId,
            amountToNeutralize
        );

        IERC20(collateralType).safeTransfer(msg.sender, collateralOwed);

        //give the user their long tokens (if any)
        if (qTokenAsCollateral != address(0)) {
            QToken(qTokenAsCollateral).mint(msg.sender, amountToNeutralize);
        }

        emit NeutralizePosition(
            msg.sender,
            qTokenShort,
            amountToNeutralize,
            collateralOwed,
            collateralType,
            qTokenAsCollateral
        );
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

            // Check that the option types match
            require(
                qTokenToMint.isCall() == qTokenForCollateral.isCall(),
                "Controller: Can't create spreads from options with different types"
            );

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

    //todo: ensure the oracle price is normalized to the amount of decimals in the strikeAsset (e.g., USDC)
    function getPayout(address _qToken, uint256 _amount)
        public
        view
        returns (
            bool isSettled,
            address payoutToken,
            uint256 payoutAmount
        )
    {
        QToken qToken = QToken(_qToken);
        isSettled = qToken.getOptionPriceStatus() == PriceStatus.SETTLED;
        if (!isSettled) {
            return (false, address(0), 0);
        }

        PriceRegistry priceRegistry =
            PriceRegistry(optionsFactory.quantConfig().priceRegistry());

        uint256 strikePrice = qToken.strikePrice();
        uint256 expiryPrice =
            priceRegistry.getSettlementPrice(
                qToken.oracle(),
                qToken.underlyingAsset(),
                qToken.expiryTime()
            );

        if (qToken.isCall()) {
            (, , uint8 underlyingDecimals) =
                AssetsRegistry(optionsFactory.quantConfig().assetsRegistry())
                    .assetProperties(qToken.underlyingAsset());

            payoutAmount = expiryPrice > strikePrice
                ? expiryPrice
                    .sub(strikePrice)
                    .mul(_amount)
                    .div(expiryPrice)
                    .mul(10**underlyingDecimals)
                    .div(10**OPTIONS_DECIMALS)
                : 0;
            payoutToken = qToken.underlyingAsset();
        } else {
            payoutAmount = strikePrice > expiryPrice
                ? (strikePrice.sub(expiryPrice)).mul(_amount).div(
                    10**OPTIONS_DECIMALS
                )
                : 0;
            payoutToken = qToken.strikeAsset();
        }
    }
}
