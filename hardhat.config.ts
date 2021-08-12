import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";
import "@openzeppelin/hardhat-upgrades";
import * as dotenv from "dotenv";
import "hardhat-contract-sizer";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "hardhat-typechain";
import { HardhatUserConfig } from "hardhat/config";
import "solidity-coverage";

dotenv.config();

const config: HardhatUserConfig = {
  networks: {
    hardhat: {
      accounts: {
        mnemonic:
          process.env.MNEMONIC ||
          "word soft garden squirrel this lift object foot someone boost certain provide",
      },
    },
  },
  solidity: {
    version: "0.7.6",
    settings: {
      metadata: {
        // do not include the metadata hash, since this is machine dependent
        // https://github.com/paulrberg/solidity-template/issues/31
        bytecodeHash: "none",
      },
      // You should disable the optimizer when debugging
      // https://hardhat.org/hardhat-network/#solidity-optimizer-support
      optimizer: {
        enabled: true,
        runs: 800,
      },
    },
  },

  contractSizer: {
    alphaSort: true,
    runOnCompile: false,
    disambiguatePaths: false,
  },

  mocha: {
    timeout: 1000000,
  },

  typechain: {
    target: "ethers-v5",
  },
};

export default config;
