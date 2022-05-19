module.exports = {
  testCommand: "hardhat test",
  compileCommand: "hardhat compile",
  skipFiles: ["external/", "test/", "mocks/", "libraries/OptionsUtils.sol", "options/QToken.sol", "utils/EIP712MetaTransaction.sol"],
};
