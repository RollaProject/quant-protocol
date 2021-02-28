import { ethers } from "hardhat";

(async () => {
  const RoundIdTest = await ethers.getContractFactory("RoundIdTest");
  const roundIdTest = await RoundIdTest.deploy();
  await roundIdTest.deployed();

  const proxyRoundId = ethers.BigNumber.from("55340232221128675793");
  console.log(
    (await roundIdTest.getLastValidRoundLoop(proxyRoundId)).toString()
  );
})();
