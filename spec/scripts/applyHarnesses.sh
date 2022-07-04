# SafeTransfer simplification
perl -0777 -i -pe 's/safeT/t/g' contracts/Controller.sol

# Virtualize functions
perl -0777 -i -pe 's/external\s*override/external virtual override/g' contracts/Controller.sol
perl -0777 -i -pe 's/internal\s*view\s*returns/internal view virtual returns/g' contracts/options/QToken.sol
perl -0777 -i -pe 's/internal\s*pure\s*returns/internal pure virtual returns/g' contracts/options/QToken.sol

perl -0777 -i -pe 's/internal view returns/internal view virtual returns/g' contracts/utils/EIP712MetaTransaction.sol

# Controller simplification
perl -0777 -i -pe 's/oracleRegistry.isOracleActive\(QToken\(_qToken\).oracle\(\)\)/true/g' contracts/Controller.sol

# QuantCalculator simplification
perl -0777 -i -pe 's/address public immutable override optionsFactory;/address public immutable override optionsFactory ;\n
     \/\/ add expiry price
     PriceWithDecimals expiryPrice;/g' contracts/QuantCalculator.sol

perl -0777 -i -pe 's/\/\/\/ @inheritdoc IQuantCalculator;\n\s*address public immutable override priceRegistry;//g' contracts/QuantCalculator.sol

perl -0777 -i -pe 's/PriceWithDecimals memory expiryPrice = IPriceRegistry\(priceRegistry\)\n\s*.getSettlementPriceWithDecimals\(oracle, expiryTime, underlyingAsset\);\n//g' contracts/QuantCalculator.sol

perl -0777 -i -pe 's/isSettled =\n\s*IPriceRegistry\(priceRegistry\).getOptionPriceStatus\(\n\s*oracle, expiryTime, underlyingAsset\n\s*\)\n\s*== PriceStatus.SETTLED;\n/isSettled = true;\n/g' contracts/QuantCalculator.sol
# Decimal simplification
perl -0777 -i -pe 's/uintToInt\(\)\);\n\s*} else \{/uintToInt\(\)\);
        } else if (_decimals == 6) {
            fixedPoint = FixedPointInt((_a * 1000000000000000000000).uintToInt());
        } else if (_decimals == 18) {
            fixedPoint = FixedPointInt((_a * 1000000000).uintToInt());
        } else {/g' contracts/libraries/QuantMath.sol

# Division simplification
perl -0777 -i -pe 's/\(10\*\*_underlyingDecimals\)/uint256\(1000000000000000000\)/g' contracts/libraries/FundsCalculator.sol

perl -0777 -i -pe 's/payoutAmount =\n\s*payoutInput.expiryPrice.isGreaterThan\(/QuantMath.FixedPointInt memory divResult = QuantMath.FixedPointInt\(computeDivision\(payoutInput.expiryPrice.value,
                                          payoutInput.strikePrice.value\)\);

        payoutAmount = payoutInput.expiryPrice.isGreaterThan\(/g' contracts/libraries/FundsCalculator.sol

perl -0777 -i -pe 's/\? payoutInput.expiryPrice.sub\(payoutInput.strikePrice\).mul\(\n\s*payoutInput.amount, true\n\s*\).div\(payoutInput.expiryPrice, true\)/\? QuantMath.FixedPointInt\(computeMultiplication\(divResult.value, payoutInput.amount.value\)\)/g' contracts/libraries/FundsCalculator.sol

perl -0777 -i -pe 's/payoutAmount =\n\s*payoutInput.strikePrice.isGreaterThan\(/QuantMath.FixedPointInt memory subResult = payoutInput.strikePrice.sub\(payoutInput.expiryPrice\);

        payoutAmount = payoutInput.strikePrice.isGreaterThan\(/g' contracts/libraries/FundsCalculator.sol

perl -0777 -i -pe 's/payoutInput.strikePrice.sub\(payoutInput.expiryPrice\).mul\(\n\s*payoutInput.amount, true\n\s*\)/QuantMath.FixedPointInt\(computeMultiplication\(subResult.value, payoutInput.amount.value\)\)/g' contracts/libraries/FundsCalculator.sol

perl -0777 -i -pe 's/collateralStrikePrice.sub\(mintStrikePrice\).div\(\n\s*collateralStrikePrice, false\n\s*\); \/\/ Call Credit Spread\n\s*}\n\s*}/QuantMath.FixedPointInt\(computeDivision\(collateralStrikePrice.value,
                  mintStrikePrice.value\)\); \/\/ Call Credit Spread
        }
   }
   function computeDivision\(
           int256 _collateralStrikePrice,
           int256 _mintStrikePrice
   \)
   internal
   pure
   returns \(int256 collateralPerOption\)    {
           int256 _SCALING_FACTOR = 1e27;
           int256 subResult = _collateralStrikePrice - _mintStrikePrice;
           collateralPerOption = subResult * _SCALING_FACTOR \/ _collateralStrikePrice;
   }
   function computeMultiplication\(
            int256 _a,
            int256 _b
    \)
    internal
    pure
    returns \(int256\) {
        int256 _SCALING_FACTOR = 1e27;
        return _a * _b \/ _SCALING_FACTOR;
    }/g' contracts/libraries/FundsCalculator.sol

# Add tokenSupplies to CollateralToken
perl -0777 -i -pe 's/address private _optionsFactory;\n/address private _optionsFactory;\n\n    mapping\(uint256 => uint256\) public tokenSupplies;\n/g' contracts/options/CollateralToken.sol
perl -0777 -i -pe 's/_mint\(recipient, collateralTokenId, amount, ""\);\n/tokenSupplies[collateralTokenId] += amount;\n\n\t\t_mint\(recipient, collateralTokenId, amount, ""\);\n/g' contracts/options/CollateralToken.sol
perl -0777 -i -pe 's/_burn\(cTokenOwner, collateralTokenId, amount\);\n/tokenSupplies[collateralTokenId] -= amount;\n\n\t\t_burn\(cTokenOwner, collateralTokenId, amount\);\n/g' contracts/options/CollateralToken.sol

# Make QToken public pure functions virtual and view
perl -0777 -i -pe 's/pure\n/view\n\t\tvirtual\n/g' contracts/options/QToken.sol
perl -0777 -i -pe 's/pure /view virtual /g' contracts/options/QToken.sol
perl -0777 -i -pe 's/public/external/g' contracts/options/QToken.sol
perl -0777 -i -pe 's/msg.sender == controller\(\)/msg.sender != address\(0\)/g' contracts/options/QToken.sol
perl -0777 -i -pe 's/pure/view/g' contracts/interfaces/IQToken.sol
perl -0777 -i -pe 's/pure/view/' contracts/libraries/FundsCalculator.sol
perl -0777 -i -pe 's/pure/view/' contracts/libraries/FundsCalculator.sol

# Remove unchecked blocks from ERC20
perl -0777 -i -pe 's/unchecked {\s*(.*)\s*}/$1/g' contracts/external/ERC20.sol

# Add the ClonesWithImmutableArgsWrapper contract to the OptionsFactory
perl -0777 -i -pe 's/QToken public immutable implementation;\n/QToken public immutable implementation;\n\n\tClonesWithImmutableArgsWrapper public immutable clonesWrapper;\n\n/g' contracts/options/OptionsFactory.sol
perl -0777 -i -pe 's/using ClonesWithImmutableArgs for address;\n//g' contracts/options/OptionsFactory.sol
perl -0777 -i -pe 's/import {ClonesWithImmutableArgs} from\s*"\@rolla-finance\/clones-with-immutable-args\/ClonesWithImmutableArgs.sol";/import "..\/..\/spec\/harness\/ClonesWithImmutableArgsWrapper.sol";/g' contracts/options/OptionsFactory.sol
perl -0777 -i -pe 's/implementation = _implementation;\n/implementation = _implementation;\n\n\t\tclonesWrapper = new ClonesWithImmutableArgsWrapper\(\);\n/g' contracts/options/OptionsFactory.sol
perl -0777 -i -pe 's/address\(implementation\).cloneDeterministic\(/clonesWrapper.cloneDeterministic\(\n\t\t\taddress\(implementation\),\n/g' contracts/options/OptionsFactory.sol
perl -0777 -i -pe 's/\(qToken, exists\) = ClonesWithImmutableArgs.predictDeterministicAddress\(\n/\(qToken, exists\) = clonesWrapper.predictDeterministicAddress\(\n/g' contracts/options/OptionsFactory.sol
perl -0777 -i -pe 's/abstract contract ERC20 is Clone/abstract contract RollaERC20 is Clone/g' contracts/external/ERC20.sol
perl -0777 -i -pe 's/contract QToken is ERC20, IQToken/contract QToken is RollaERC20, IQToken/g' contracts/options/QToken.sol

# Add collateralTokendIds to the CollateralToken
perl -0777 -i -pe 's/override idToInfo;\n/override idToInfo;\n\n    uint256[] public collateralTokenIds;\n/g' contracts/options/CollateralToken.sol
# perl -0777 -i -pe 's/emit CollateralTokenCreated\(_qTokenAddress, address\(0\), id\);/collateralTokenIds.push\(id\);\n\n        emit CollateralTokenCreated\(_qTokenAddress, address\(0\), id\);/g' contracts/options/CollateralToken.sol
# perl -0777 -i -pe 's/emit CollateralTokenCreated\(_qTokenAddress, _qTokenAsCollateral, id\);/collateralTokenIds.push\(id\);\n\n        emit CollateralTokenCreated\(_qTokenAddress, _qTokenAsCollateral, id\);/g' contracts/options/CollateralToken.sol
perl -0777 -i -pe 's/}\n}/}\n    function getCollateralTokensLength\(\) external view returns \(uint256\) {\n        return collateralTokenIds.length;\n    }\n}/g' contracts/options/CollateralToken.sol
