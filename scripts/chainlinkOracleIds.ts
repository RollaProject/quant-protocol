import { ethers } from "hardhat";

(async () => {
  const RoundIdTest = await ethers.getContractFactory("RoundIdTest");
  const roundIdTest = await RoundIdTest.deploy();
  await roundIdTest.deployed();

  const proxyRoundId = ethers.BigNumber.from("55340232221128657476");
  console.log((await roundIdTest.submitPrice(1604786710, 50)).toString());
})();
