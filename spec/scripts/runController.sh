certoraRun spec/harness/ControllerHarness.sol spec/harness/DummyERC20A.sol \
spec/harness/DummyERC20B.sol spec/harness/QTokenA.sol spec/harness/QTokenB.sol \
	contracts/options/OptionsFactory.sol \
    --verify ControllerHarness:spec/controller.spec --settings -ignoreViewFunctions \
	--solc solc7.6 \
	--rule check \
	--cache controller \
	--staging --msg "Controller with env "