// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma abicoder v2;

import "../../contracts/interfaces/IQuantCalculator.sol";
import "../../contracts/interfaces/IOptionsFactory.sol";
import "../../contracts/interfaces/IQToken.sol";
import "../../contracts/interfaces/IPriceRegistry.sol";

//TODO: Stop taking optionsFactory as params in here as its an anti-pattern and frontend will need to pass it.
contract QuantCalculatorHarness is IQuantCalculator {

    uint8 public constant override OPTIONS_DECIMALS = 0;

    IQuantCalculator calcOriginal;
    

    mapping (address => address) public qTokenToCollateralType;
    // a symbolic mapping form (qToken, qtokenLong, amount) to collateralRequirement 
    mapping (address => mapping( address => mapping( uint256 => uint256) )) public collateralRequirement;
    // a symbolic mapping form (_collateralTokenId, amount) to claimableCollateral 
    mapping (uint256 => mapping( uint256 => uint256) ) public claimableCollateral;
    // a symbolic mapping form (qToken, amount) to exercisePayout 
    mapping (address => mapping( uint256 => uint256) ) public exercisePayout;
    

    function calculateClaimableCollateral(
        uint256 _collateralTokenId,
        uint256 _amount,
        address _optionsFactory,
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

        IOptionsFactory optionsFactory = IOptionsFactory(_optionsFactory);

        amountToClaim = _amount == 0
            ? optionsFactory.collateralToken().balanceOf(
                msgSender,
                _collateralTokenId
            )
            : _amount;

        (address _qTokenShort, address qTokenAsCollateral) =
            optionsFactory.collateralToken().idToInfo(_collateralTokenId);

        returnableCollateral = claimableCollateral[_collateralTokenId][amountToClaim];
        collateralAsset = qTokenToCollateralType[_qTokenShort];
    }

    function getNeutralizationPayout(
        address _qTokenLong,
        address _qTokenShort,
        uint256 _amountToNeutralize,
        address _optionsFactory
    )
        external
        view
        override
        returns (address collateralType, uint256 collateralOwed)
    {
        return calcOriginal.getNeutralizationPayout(_qTokenLong,_qTokenShort,_amountToNeutralize,_optionsFactory);
    }

    function getCollateralRequirement(
        address _qTokenToMint,
        address _qTokenForCollateral,
        address _optionsFactory,
        uint256 _amount
    )
        external
        view
        override
        returns (address collateral, uint256 collateralAmount)
    {
        collateralAmount = collateralRequirement[_qTokenToMint][_qTokenForCollateral][_amount];
        collateral =  qTokenToCollateralType[_qTokenToMint];
    }


    


    function getExercisePayout(
        address _qToken,
        address _optionsFactory,
        uint256 _amount
    )
        external
        view
        override
        returns (
            bool isSettled,
            address payoutToken,
            uint256 payoutAmount
        )
    {
        IQToken qToken = IQToken(_qToken);
        isSettled = qToken.getOptionPriceStatus() == PriceStatus.SETTLED;
        payoutAmount = exercisePayout[_qToken][_amount];
        payoutToken = qTokenToCollateralType[_qToken];
    }
}
