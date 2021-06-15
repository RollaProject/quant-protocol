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
    //TODO: msgSender balanceOf should be moved to controller
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
        return calcOriginal.calculateClaimableCollateral(_collateralTokenId,_amount,_optionsFactory,msgSender);
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
        address x;
        uint y;
        (x,y) = calcOriginal.getCollateralRequirement(_qTokenToMint,_qTokenForCollateral,_optionsFactory,_amount);
        //if (IQToken(_qTokenToMint).isCall()) {y = _amount;}//Gadi
        return (qTokenToCollateralType[_qTokenToMint],y);
    }
    mapping (address => address) public qTokenToCollateralType;
    
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
        return calcOriginal.getExercisePayout(_qToken,_optionsFactory,_amount);
    }
}
