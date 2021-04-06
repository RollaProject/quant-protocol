// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

interface ICollateralToken {
    function createCollateralToken(
        address _qTokenAddress,
        address _qTokenAsCollateral
    ) external returns (uint256 id);

    function mintCollateralToken(
        address recipient,
        uint256 collateralTokenId,
        uint256 amount
    ) external;

    function burnCollateralToken(
        address owner,
        uint256 collateralTokenId,
        uint256 amount
    ) external;

    function mintCollateralTokenBatch(
        address recipient,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external;

    function burnCollateralTokenBatch(
        address owner,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external;

    function getCollateralTokenId(address _qToken, address _qTokenAsCollateral)
    external
    pure
    returns (uint256 id);
}
