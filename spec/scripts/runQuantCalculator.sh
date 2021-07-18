certoraRun contracts/QuantCalculator.sol spec/harness/DummyERC20A.sol \
           spec/harness/DummyERC20B.sol spec/harness/QTokenA.sol spec/harness/QTokenB.sol \
           spec/harness/CollateralTokenHarness.sol \
            --verify QuantCalculator:spec/quantCalculator.spec --settings -optimisticReturnsize=true,-postProcessCounterExamples=true,-smt_nonLinearArithmetic=true,-ciMode=true \
            --optimistic_loop \
            --staging --msg "QuantCalculator"



