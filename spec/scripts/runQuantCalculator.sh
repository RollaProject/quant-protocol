certoraRun contracts/QuantCalculator.sol spec/harness/DummyERC20A.sol \
           spec/harness/DummyERC20B.sol spec/harness/QTokenA.sol spec/harness/QTokenB.sol \
           spec/harness/CollateralTokenHarness.sol \
            --verify QuantCalculator:spec/quantCalculator.spec --settings -optimisticReturnsize=true,-postProcessCounterExamples=true,-smt_nonLinearArithmetic=true \
            --solc solc7.6 \
            --optimistic_loop \
            --rule $1 \
            --staging --msg "collateralZero $1"



