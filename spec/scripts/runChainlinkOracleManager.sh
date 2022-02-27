certoraRun spec/harness/ChainlinkOracleManagerWrapper.sol  \
	--verify ChainlinkOracleManagerWrapper:spec/chainlinkOracleManager.spec --settings -ciMode=true,-optimisticReturnsize=true,-ignoreViewFunctions,-postProcessCounterExamples=true,-enableStorageAnalysis=true \
	--link ChainlinkOracleManagerWrapper:chainlinkOracleManager=ChainlinkOracleManagerWrapper \
	# --optimistic_loop \
	# --staging \
	# --cache chainlinkOracleManager \
	# --msg "ChainlinkOracleManager"