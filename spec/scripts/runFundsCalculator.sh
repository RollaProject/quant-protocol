certoraRun spec/harness/FundsCalculatorWrapper.sol contracts/libraries/FundsCalculator.sol spec/harness/DummyERC20A.sol \
           spec/harness/DummyERC20B.sol spec/harness/QTokenA.sol spec/harness/QTokenB.sol \
            --verify FundsCalculatorWrapper:spec/fundsCalculator.spec \
            --rule checkRule1 \
            --settings -assumeUnwindCond,-postProcessCounterExamples=true \
            --solc solc7.6  \
            --staging --msg "test 10"


# Rule 3
# test 1 - checkPutCollateralRequirement-rule3 with 1) strikePrices < 10^6; 2) base decimal in quantMath = 6 --- passes
# test 2 - checkPutCollateralRequirement-rule3 with 1) strikePrices < 10^6; 2) base decimal in quantMath = 27 --- passes
# test 3 - checkPutCollateralRequirement-rule3 with 1) strikePrices no restriction; 2) base decimal in quantMath = 27 ---fails |
#           overflow in multiplication due to large value of collateralStrikePrice1 * 10^21. As USDC has decimal 6 so in quantMath
#           collateralStrikePrice is multiplied with 10^21 and the product is greater than 2^256. Due to norevert and overapproximation
#           we continue with a value that is not the same as the expected value.
# test 4 - same test as above with the revert checks --- fails | reverts at multiplication overflow.
# test 5 - same as test 2 but with revert checks --- passes


# Rule 5 (choosing the test with least assumptions from above)
# test 6 - (same as test 2) but for checkPutCollateralRequirement2-rule5 with 1) strikePrices < 10^7; 2) base decimal in quantMath = 27 --- passes

# Rule 2
# test 7 - checkCallCollateralRequirement-rule2 with 1) strikePrices < 10^6; 2) base decimal in quantMath = 27 --- fails |
#           underlyingDecimals = id = 29
#           mintStrikePrice = 3
#
#           collateralStrikePrice1 = 0 ===> collateralPerOption = 2 (based on overapproximation of div operator)
#           collateralStrikePrice2 = 2 ===> collateralPerOption = 0
# test 8 - same as test 7, but with reverts --- fails | reverts at division by 0??


# Rule 4
# test 9 - checkCallCollateralRequirement2-rule4  strikePrices < 10^6; 2) base decimal in quantMath = 27 --- passes

# Rule 1
# test 10 - checkRule1 isCall() = ALWAYS(0)