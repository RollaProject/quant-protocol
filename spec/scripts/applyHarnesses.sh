# SafeTransfer simplification
perl -0777 -i -pe 's/safeT/t/g' contracts/Controller.sol

# Virtualize functions
perl -0777 -i -pe 's/external\s*override\s*nonReentrant/external virtual override nonReentrant/g' contracts/Controller.sol
perl -0777 -i -pe 's/internal\s*view\s*returns/internal view virtual returns/g' contracts/options/QToken.sol
perl -0777 -i -pe 's/internal\s*pure\s*returns/internal pure virtual returns/g' contracts/options/QToken.sol

perl -0777 -i -pe 's/internal view returns/internal view virtual returns/g' contracts/utils/EIP712MetaTransaction.sol

# Decimal simplification
perl -0777 -i -pe 's/\(\(_a.div\(10\*\*exp\)\).uintToInt\(\)\);\s*} else \{/\(\(_a.div\(10\*\*exp\)\).uintToInt\(\)\);
        } else if (_decimals == 6) {
            fixedPoint = FixedPointInt((_a.mul(1000000000000000000000)).uintToInt());
        } else if (_decimals == 18) {
            fixedPoint = FixedPointInt((_a.mul(1000000000)).uintToInt());
        } else {/g' contracts/libraries/QuantMath.sol

# Division simplification
perl -0777 -i -pe 's/Registry.sol";/Registry.sol"    ;\nimport "\@openzeppelin\/contracts\/math\/SignedSafeMath.sol";/g' contracts/libraries/FundsCalculator.sol
perl -0777 -i -pe 's/using SafeMath for uint256;/using SafeMath for uint256    ;\n    using SignedSafeMath for int256;/g' contracts/libraries/FundsCalculator.sol
perl -0777 -i -pe 's/\(10\*\*_underlyingDecimals\)/uint256\(1000000\)/g' contracts/libraries/FundsCalculator.sol

perl -0777 -i -pe 's/\? payoutInput\n\s*.expiryPrice\n\s*.sub\(payoutInput.strikePrice\)\n\s*.mul\(payoutInput.amount\)\n\s*.div\(payoutInput.expiryPrice\)/\? \(QuantMath.FixedPointInt\(computeDivision\(payoutInput.expiryPrice.value,
               payoutInput.strikePrice.value\)\)\).mul\(payoutInput.amount\)/g' contracts/libraries/FundsCalculator.sol

perl -0777 -i -pe 's/\(collateralStrikePrice.sub\(mintStrikePrice\)\).div\(\n\s*collateralStrikePrice\n\s*\); \/\/ Call Credit Spread\n\s*}\n\s*}/QuantMath.FixedPointInt\(computeDivision\(collateralStrikePrice.value,
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
           int256 subResult = _collateralStrikePrice.sub\(_mintStrikePrice\);
           collateralPerOption = subResult.mul\(_SCALING_FACTOR\) \/ _collateralStrikePrice;
   }/g' contracts/libraries/FundsCalculator.sol