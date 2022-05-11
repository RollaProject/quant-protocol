# SafeTransfer simplification
perl -0777 -i -pe 's/safeT/t/g' contracts/Controller.sol

# Virtualize functions
perl -0777 -i -pe 's/external\s*override\s*nonReentrant/external virtual override nonReentrant/g' contracts/Controller.sol
perl -0777 -i -pe 's/internal\s*view\s*returns/internal view virtual returns/g' contracts/options/QToken.sol
perl -0777 -i -pe 's/internal\s*pure\s*returns/internal pure virtual returns/g' contracts/options/QToken.sol

perl -0777 -i -pe 's/internal view returns/internal view virtual returns/g' contracts/utils/EIP712MetaTransaction.sol

# Controller simplification
perl -0777 -i -pe 's/require\(\s*IOracleRegistry\(\s*IOptionsFactory\(optionsFactory\).quantConfig\(\).protocolAddresses\(\s*ProtocolValue.encode\("oracleRegistry"\)\s*\)\s*\)\s*.isOracleActive\(qToken.oracle\(\)\)/require\(true/g' contracts/Controller.sol



# QuantCalculator simplification
perl -0777 -i -pe 's/address public immutable override optionsFactory;/address public immutable override optionsFactory ;\n
     \/\/ add expiry price
     PriceWithDecimals expiryPrice;/g' contracts/QuantCalculator.sol


perl -0777 -i -pe 's/IPriceRegistry priceRegistry =\s*IPriceRegistry\(\s*IOptionsFactory\(optionsFactory\).quantConfig\(\).protocolAddresses\(\s*ProtocolValue.encode\("priceRegistry"\)\s*\)\s*\);/\/\/ IPriceRegistry priceRegistry =
            \/\/ IPriceRegistry\(
            \/\/     IOptionsFactory\(optionsFactory\).quantConfig\(\).protocolAddresses\(
            \/\/         ProtocolValue.encode\("priceRegistry"\)
            \/\/     \)
            \/\/ \);/g' contracts/QuantCalculator.sol


perl -0777 -i -pe 's/PriceWithDecimals memory expiryPrice =\s*priceRegistry.getSettlementPriceWithDecimals\(\s*qTokenShort.oracle\(\),\s*qTokenShort.underlyingAsset\(\),\s*qTokenShort.expiryTime\(\)\s*\);/\/\/ PriceWithDecimals memory expiryPrice =
            \/\/ priceRegistry.getSettlementPriceWithDecimals\(
            \/\/     qTokenShort.oracle\(\),
            \/\/     qTokenShort.underlyingAsset\(\),
            \/\/     qTokenShort.expiryTime\(\)
            \/\/ \);/g' contracts/QuantCalculator.sol

perl -0777 -i -pe 's/PriceWithDecimals memory expiryPrice =\s*priceRegistry.getSettlementPriceWithDecimals\(\s*qToken.oracle\(\),\s*underlyingAsset,\s*qToken.expiryTime\(\)\s*\);/\/\/ PriceWithDecimals memory expiryPrice =
            \/\/ priceRegistry.getSettlementPriceWithDecimals\(
            \/\/     qToken.oracle\(\),
            \/\/     underlyingAsset,
            \/\/     qToken.expiryTime\(\)
            \/\/ \);/g' contracts/QuantCalculator.sol

perl -0777 -i -pe 's/isSettled = qToken.getOptionPriceStatus\(\) == PriceStatus.SETTLED;/isSettled = true;/g' contracts/QuantCalculator.sol

# Decimal simplification
perl -0777 -i -pe 's/\(\(_a.div\(10\*\*exp\)\).uintToInt\(\)\);\s*} else \{/\(\(_a.div\(10\*\*exp\)\).uintToInt\(\)\);
        } else if (_decimals == 6) {
            fixedPoint = FixedPointInt((_a.mul(1000000000000000000000)).uintToInt());
        } else if (_decimals == 18) {
            fixedPoint = FixedPointInt((_a.mul(1000000000)).uintToInt());
        } else {/g' contracts/libraries/QuantMath.sol

# Division simplification
# perl -0777 -i -pe 's/\(10\*\*_underlyingDecimals\)/uint256\(1000000\)/g' contracts/libraries/FundsCalculator.sol

perl -0777 -i -pe 's/payoutAmount = payoutInput.expiryPrice.isGreaterThan\(/QuantMath.FixedPointInt memory divResult = QuantMath.FixedPointInt\(computeDivision\(payoutInput.expiryPrice.value,
                                          payoutInput.strikePrice.value\)\);

        payoutAmount = payoutInput.expiryPrice.isGreaterThan \(/g' contracts/libraries/FundsCalculator.sol

perl -0777 -i -pe 's/\? payoutInput\n\s*.expiryPrice\n\s*.sub\(payoutInput.strikePrice\)\n\s*.mul\(payoutInput.amount, true\)\n\s*.div\(payoutInput.expiryPrice, true\)/\? QuantMath.FixedPointInt\(computeMultiplication\(divResult.value, payoutInput.amount.value\)\)/g' contracts/libraries/FundsCalculator.sol

perl -0777 -i -pe 's/payoutAmount = payoutInput.strikePrice.isGreaterThan\(/QuantMath.FixedPointInt memory subResult = payoutInput.strikePrice.sub\(payoutInput.expiryPrice\);

        payoutAmount = payoutInput.strikePrice.isGreaterThan \(/g' contracts/libraries/FundsCalculator.sol

perl -0777 -i -pe 's/\(payoutInput.strikePrice.sub\(payoutInput.expiryPrice\)\).mul\(\n\s*payoutInput.amount,\n\s*true\n\s*\)/QuantMath.FixedPointInt\(computeMultiplication\(subResult.value, payoutInput.amount.value\)\)/g' contracts/libraries/FundsCalculator.sol

perl -0777 -i -pe 's/\(collateralStrikePrice.sub\(mintStrikePrice\)\).div\(\n\s*collateralStrikePrice,\n\s*false\n\s*\); \/\/ Call Credit Spread\n\s*}\n\s*}/QuantMath.FixedPointInt\(computeDivision\(collateralStrikePrice.value,
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
perl -0777 -i -pe 's/override collateralTokenIds;\n/override collateralTokenIds;\n\n    mapping\(uint256 => uint256\) public tokenSupplies;\n/g' contracts/options/CollateralToken.sol
perl -0777 -i -pe 's/emit CollateralTokenMinted\(recipient, collateralTokenId, amount\);\n/tokenSupplies[collateralTokenId] += amount;\n\n\t\temit CollateralTokenMinted\(recipient, collateralTokenId, amount\);\n/g' contracts/options/CollateralToken.sol
perl -0777 -i -pe 's/emit CollateralTokenBurned\(owner, collateralTokenId, amount\);/tokenSupplies[collateralTokenId] -= amount;\n\n\t\temit CollateralTokenBurned\(owner, collateralTokenId, amount\);/g' contracts/options/CollateralToken.sol
perl -0777 -i -pe 's/emit CollateralTokenMinted\(recipient, ids\[i\], amounts\[i\]\);/tokenSupplies[ids[i]] += amounts[i];\n\t\t\temit CollateralTokenMinted\(recipient, ids[i], amounts[i]\);/g' contracts/options/CollateralToken.sol
perl -0777 -i -pe 's/emit CollateralTokenBurned\(owner, ids\[i\], amounts\[i\]\);/tokenSupplies[ids[i]] -= amounts[i];\n\t\t\temit CollateralTokenBurned(owner, ids[i], amounts[i]);/g' contracts/options/CollateralToken.sol
