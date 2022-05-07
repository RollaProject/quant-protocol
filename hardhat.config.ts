import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";
import "@openzeppelin/hardhat-upgrades";
import "@tenderly/hardhat-tenderly";
import "@typechain/hardhat";
import * as dotenv from "dotenv";
import "hardhat-contract-sizer";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "hardhat-gas-reporter";
import { TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS } from "hardhat/builtin-tasks/task-names";
import { HardhatUserConfig, subtask } from "hardhat/config";
import "solidity-coverage";

subtask(TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS).setAction(
  async (_, __, runSuper) => {
    const paths = await runSuper();

    return paths.filter((p: string) => !p.endsWith(".t.sol"));
  }
);

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
    mumbai: {
      url: `https://polygon-mumbai.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
      chainId: 80001,
      accounts: {
        mnemonic:
          process.env.MNEMONIC ||
          "word soft garden squirrel this lift object foot someone boost certain provide",
      },
    },

    bscTestnet: {
      url: process.env.BSC_TESTNET_URL || "",
      chainId: 97,
      accounts: {
        mnemonic:
          process.env.MNEMONIC ||
          "word soft garden squirrel this lift object foot someone boost certain provide",
      },
    },
  },
  solidity: {
    version: "0.8.13",
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
        runs: 1000000,
      },
      viaIR: true,
      outputSelection: {
        "*": {
          "*": [
            "metadata",
            "evm.bytecode", // Enable the metadata and bytecode outputs of every single contract.
            "evm.bytecode.sourceMap", // Enable the source map output of every single contract.
            "storageLayout",
          ],
          "": [
            "ast", // Enable the AST output of every single file.
          ],
        },
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
    outDir: "typechain",
  },

  gasReporter: {
    enabled: process.env.REPORT_GAS ? true : false,
    currency: "USD",
    coinmarketcap: process.env.CMC_API_KEY || "",
    token: process.env.GAS_TOKEN || "BNB",
    gasPriceApi:
      process.env.GAS_PRICE_API ||
      `https://api.bscscan.com/api?module=proxy&action=eth_gasPrice&apikey=${process.env.BSCSCAN_API_KEY}`,
  },

  tenderly: {
    project: process.env.ETH_NETWORK
      ? `rolla-v1-${process.env.ETH_NETWORK}`
      : "rolla-v1-hardhat",
    username: process.env.TENDERLY_USERNAME || "",
  },
};

export default config;
