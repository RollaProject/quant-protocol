certoraRun spec/harness/ControllerHarness.sol spec/harness/DummyERC20A.sol \
spec/harness/DummyERC20B.sol spec/harness/QTokenA.sol spec/harness/QTokenB.sol contracts/QuantCalculator.sol \
	contracts/options/OptionsFactory.sol spec/harness/CollateralTokenHarness.sol \
	--verify ControllerHarness:spec/controller.spec --settings -ignoreViewFunctions,-postProcessCounterExamples=true \
	--solc solc7.6 \
	--rule $1 \
	--staging --msg "Controller : $1 "



#contracts/QuantCalculator.sol \
#	--link ControllerHarness:quantCalculator=QuantCalculator \
    
	