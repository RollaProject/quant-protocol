import { ethers } from "hardhat";
import aggregator from "../artifacts/contracts/chainlink-oracle-roundId/IAccessControlledAggregator.sol/IAccessControlledAggregator.json";

(async () => {
  const [deployer] = await ethers.getSigners();
  // console.log(await deployer.getAddress());
  const aggregatorImplementation = new ethers.Contract(
    "0x00c7A37B03690fb9f41b5C5AF8131735C7275446",
    aggregator.abi,
    deployer
  );
  const RoundIdTest = await ethers.getContractFactory("RoundIdTest");
  const roundIdTest = await RoundIdTest.deploy();
  await roundIdTest.deployed();

  // Get the roundId corresponding to the current round of the aggregator implementation
  const roundId = await aggregatorImplementation.latestRound();

  console.log(await roundIdTest.getLastValidRound(roundId));
})();
