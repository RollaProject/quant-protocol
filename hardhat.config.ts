import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "hardhat-typechain";
import { HardhatUserConfig } from "hardhat/config";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [{ version: "0.7.6" }],
  },

  mocha: {
    timeout: 1000000,
  },

  typechain: {
    target: "ethers-v5",
  },
};

export default config;
