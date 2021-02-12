import { ethers, upgrades } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";

const deployFunc: DeployFunction = async ({ getUnnamedAccounts }) => {
  const [admin] = await getUnnamedAccounts();
  const QuantConfig = await ethers.getContractFactory("QuantConfig");
  const quantConfig = await upgrades.deployProxy(QuantConfig, [admin]);
  await quantConfig.deployed();
};

export default deployFunc;
