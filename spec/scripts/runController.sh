certoraRun spec/harness/ControllerHarness.sol spec/harness/DummyERC20A.sol \
spec/harness/DummyERC20B.sol spec/harness/QTokenA.sol spec/harness/QTokenB.sol \
        node_modules/@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol \
	contracts/options/OptionsFactory.sol spec/harness/CollateralTokenHarness.sol spec/harness/QuantCalculatorHarness.sol \
	--verify ControllerHarness:spec/controller.spec --settings -ciMode=true,-optimisticReturnsize=true,-ignoreViewFunctions,-postProcessCounterExamples=true,-enableStorageAnalysis=true \
	--link ControllerHarness:quantCalculator=QuantCalculatorHarness \
	--optimistic_loop \
	--staging \
	--cache controllerQuant \
	--msg "Controller"