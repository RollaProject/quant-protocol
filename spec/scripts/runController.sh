certoraRun spec/harness/ControllerHarness.sol spec/harness/DummyERC20A.sol \
spec/harness/DummyERC20B.sol spec/harness/QTokenA.sol spec/harness/QTokenB.sol contracts/QuantCalculator.sol \
        node_modules/@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol \
	contracts/options/OptionsFactory.sol spec/harness/CollateralTokenHarness.sol spec/harness/QuantCalculatorHarness.sol \
	--verify ControllerHarness:spec/controller.spec --settings -optimisticReturnsize=true,-ignoreViewFunctions,-postProcessCounterExamples=true \
	--solc solc7.6 \
	--rule $1 \
	--link ControllerHarness:quantCalculator=QuantCalculatorHarness \
	--optimistic_loop \
	--cache QuantController \
	--staging --msg "Controller : $1 "



#contracts/QuantCalculator.sol \
#	--link ControllerHarness:quantCalculator=QuantCalculator \
    
	
