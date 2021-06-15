# SafeTransfer simplification
perl -0777 -i -pe 's/safeT/t/g' contracts/Controller.sol

# Virtualize functions
perl -0777 -i -pe 's/external\s*override\s*nonReentrant/external virtual override nonReentrant/g' contracts/Controller.sol
perl -0777 -i -pe 's/internal\s*view\s*returns/internal view virtual returns/g' contracts/options/QToken.sol
perl -0777 -i -pe 's/internal\s*pure\s*returns/internal pure virtual returns/g' contracts/options/QToken.sol

perl -0777 -i -pe 's/internal view returns/internal view virtual returns/g' contracts/utils/EIP712MetaTransaction.sol

# Decimal simplification
perl -0777 -i -pe 's/fixedPoint = FixedPointInt\(\(_a.div\(10\*\*exp\)\).uintToInt\(\)\);\s*} else {/fixedPoint = FixedPointInt\(\(_a.div\(10\*\*exp\)\).uintToInt\(\)\);\n        } else if (_decimals == 6) {\n            fixedPoint = FixedPointInt((_a.mul(1000000000000000000000)).uintToInt());\n        } else if (_decimals == 18) {\n            fixedPoint = FixedPointInt((_a.mul(1000000000)).uintToInt());\n        } else {/g' contracts/libraries/QuantMath.sol

# Division simplification
perl -0777 -i -pe 's/Registry.sol";\n\n\/\/TODO/Registry.sol";\nimport "\@openzeppelin\/contracts\/math\/SignedSafeMath.sol";\n\n\/\/TODO/g' contracts/libraries/FundsCalculator.sol
perl -0777 -i -pe 's/using SafeMath for uint256;\n\s*using QuantMath/using SafeMath for uint256;\n    using SignedSafeMath for int256;\n    using QuantMath/g' contracts/libraries/FundsCalculator.sol
perl -0777 -i -pe 's/\(10\*\*_underlyingDecimals\)/uint256\(1000000\)/g' contracts/libraries/FundsCalculator.sol
perl -0777 -i -pe 's/\? payoutInput\n\s*.expiryPrice\n\s*.sub\(payoutInput.strikePrice\)\n\s*.mul\(payoutInput.amount\)\n\s*.div\(payoutInput.expiryPrice\)/\? \(QuantMath.FixedPointInt\(computeDivision\(payoutInput.expiryPrice.value,\n               payoutInput.strikePrice.value\)\)\).mul\(payoutInput.amount\)/g' contracts/libraries/FundsCalculator.sol

perl -0777 -i -pe 's/\(collateralStrikePrice.sub\(mintStrikePrice\)\).div\(\n\s*collateralStrikePrice\n\s*\); \/\/ Call Credit Spread\n\s*}\n\s*}/QuantMath.FixedPointInt\(computeDivision\(collateralStrikePrice.value,\n                  mintStrikePrice.value\)\); \/\/ Call Credit Spread\n         }\n    }\n    function computeDivision\(\n        int256 _collateralStrikePrice,\n        int256 _mintStrikePrice\n    \)\n    internal\n    pure\n    returns \(int256 collateralPerOption\)    {\n        int256 _SCALING_FACTOR = 1e27;\n        int256 subResult = _collateralStrikePrice.sub\(_mintStrikePrice\);\n        collateralPerOption = subResult.mul\(_SCALING_FACTOR\) \/ _collateralStrikePrice;\n    }/g' contracts/libraries/FundsCalculator.sol