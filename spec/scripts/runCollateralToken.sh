certoraRun spec/harness/CollateralTokenHarness.sol \
--verify CollateralTokenHarness:spec/collateralToken.spec \
--settings -assumeUnwindCond,-ciMode=true --cache CollateralToken \
--staging --msg "CollateralToken"