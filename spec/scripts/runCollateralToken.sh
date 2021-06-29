certoraRun spec/harness/CollateralTokenHarness.sol \
--verify CollateralTokenHarness:spec/collateralToken.spec \
--settings -assumeUnwindCond --cache CollateralToken \
--solc solc7.6  \
--staging --msg "CollateralToken"