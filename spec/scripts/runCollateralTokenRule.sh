certoraRun spec/harness/CollateralTokenHarness.sol \
--verify CollateralTokenHarness:spec/collateralToken.spec \
--settings -assumeUnwindCond --cache OptionMarket \
--rule $1 \
--msg "CollateralToken $1"