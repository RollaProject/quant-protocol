import "@nomiclabs/hardhat-waffle";
import { HardhatUserConfig } from "hardhat/config";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [{ version: "0.7.6" }],
  },

  mocha: {
    timeout: 1000000,
  },
};

export default config;
