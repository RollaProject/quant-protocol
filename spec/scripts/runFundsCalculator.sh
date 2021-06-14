certoraRun spec/harness/FundsCalculatorWrapper.sol contracts/libraries/FundsCalculator.sol spec/harness/DummyERC20A.sol \
           spec/harness/DummyERC20B.sol spec/harness/QTokenA.sol spec/harness/QTokenB.sol \
            --verify FundsCalculatorWrapper:spec/fundsCalculator.spec \
            --settings -assumeUnwindCond,-postProcessCounterExamples=true,-smt_nonLinearArithmetic=true\
            --solc solc7.6 \
            --staging --msg "check all successful"
