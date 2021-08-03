// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.0;
pragma abicoder v2;

import "../../contracts/interfaces/IQuantCalculator.sol";
import "../../contracts/interfaces/IOptionsFactory.sol";
import "../../contracts/interfaces/IQToken.sol";
import "../../contracts/interfaces/IPriceRegistry.sol";

contract QuantCalculatorHarness is IQuantCalculator {
    modifier validQToken(address _qToken) {
        require(
            IOptionsFactory(optionsFactory).isQToken(_qToken),
            "QuantCalculator: Invalid QToken address"
        );

        _;
    }

    modifier validQTokenAsCollateral(address _qTokenAsCollateral) {
        if (_qTokenAsCollateral != address(0)) {
            // it could be the zero address for the qTokenAsCollateral for non-spreads
            require(
                IOptionsFactory(optionsFactory).isQToken(_qTokenAsCollateral),
                "QuantCalculator: Invalid QToken address"
            );
        }

        _;
    }

    // a symbolic mapping form (qToken, qtokenLong, amount) to collateralRequirement
    mapping(address => mapping(address => mapping(uint256 => uint256)))
        public collateralRequirement;
    // a symbolic mapping form (_collateralTokenId, amount) to claimableCollateral
    mapping(uint256 => mapping(uint256 => uint256)) public claimableCollateral;
    // a symbolic mapping form (qToken, amount) to exercisePayout
    mapping(address => mapping(uint256 => uint256)) public exercisePayout;
    // a symbolic mapping form (qToken, qtokenLong, amount) to getNeutralizationPayout
    mapping(address => mapping(address => mapping(uint256 => uint256)))
        public neutralizationPayout;

    uint8 public constant override OPTIONS_DECIMALS = 0;

    IQuantCalculator calcOriginal;
    address public override optionsFactory;

    mapping(address => address) public qTokenToCollateralType;

    function getClaimableCollateralValue(
        uint256 _collateralTokenId,
        uint256 _amount
    ) internal view returns (uint256) {
        return claimableCollateral[_collateralTokenId][_amount];
    }

    function getCollateralRequirementValue(
        address _qTokenToMint,
        address _qTokenForCollateral,
        uint256 _amount
    ) internal view returns (uint256) {
        return
            collateralRequirement[_qTokenToMint][_qTokenForCollateral][_amount];
    }

    function getExercisePayoutValue(address _qToken, uint256 _amount)
        internal
        view
        returns (uint256)
    {
        return exercisePayout[_qToken][_amount];
    }

    function getNeutralizationPayoutValue(
        address _qTokenToMint,
        address _qTokenForCollateral,
        uint256 _amount
    ) internal view returns (uint256) {
        return
            neutralizationPayout[_qTokenToMint][_qTokenForCollateral][_amount];
    }

    function calculateClaimableCollateral(
        uint256 _collateralTokenId,
        uint256 _amount,
        address msgSender
    )
        external
        view
        override
        returns (
            uint256 returnableCollateral,
            address collateralAsset,
            uint256 amountToClaim
        )
    {
        amountToClaim = _amount == 0
            ? IOptionsFactory(optionsFactory).collateralToken().balanceOf(
                msgSender,
                _collateralTokenId
            )
            : _amount;

        (address _qTokenShort, address qTokenAsCollateral) =
            IOptionsFactory(optionsFactory).collateralToken().idToInfo(
                _collateralTokenId
            );

        returnableCollateral = getClaimableCollateralValue(
            _collateralTokenId,
            amountToClaim
        );
        collateralAsset = qTokenToCollateralType[_qTokenShort];
    }

    function getNeutralizationPayout(
        address _qTokenLong,
        address _qTokenShort,
        uint256 _amountToNeutralize
    )
        external
        view
        override
        returns (address collateralType, uint256 collateralOwed)
    {
        collateralOwed = getNeutralizationPayoutValue(
            _qTokenLong,
            _qTokenShort,
            _amountToNeutralize
        );
        collateralType = qTokenToCollateralType[_qTokenShort];
    }

    function getCollateralRequirement(
        address _qTokenToMint,
        address _qTokenForCollateral,
        uint256 _amount
    )
        external
        view
        override
        validQToken(_qTokenToMint)
        validQTokenAsCollateral(_qTokenForCollateral)
        returns (address collateral, uint256 collateralAmount)
    {
        collateralAmount = getCollateralRequirementValue(
            _qTokenToMint,
            _qTokenForCollateral,
            _amount
        );
        collateral = qTokenToCollateralType[_qTokenToMint];
    }

    function getExercisePayout(address _qToken, uint256 _amount)
        external
        view
        override
        validQToken(_qToken)
        returns (
            bool isSettled,
            address payoutToken,
            uint256 payoutAmount
        )
    {
        IQToken qToken = IQToken(_qToken);
        isSettled = qToken.getOptionPriceStatus() == PriceStatus.SETTLED;
        payoutAmount = getExercisePayoutValue(_qToken, _amount);
        payoutToken = qTokenToCollateralType[_qToken];
    }
}
