certoraRun spec/harness/ControllerHarness.sol \
    --verify ControllerHarness:spec/sanity.spec \
	--solc solc7.6 \
	--staging --msg "Controller sanity check"