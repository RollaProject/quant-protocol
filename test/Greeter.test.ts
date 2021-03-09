import { ethers } from "hardhat";
import { expect } from "chai";
import { waffle } from "hardhat";
const provider = waffle.provider;
import SOME_DEPENDENCY from "../artifacts/contracts/SomeDependency.sol/SomeDependency.json";
import { deployMockContract } from "@ethereum-waffle/mock-contract";

describe("Greeter", function () {
  it("Should return the new greeting once it's changed", async function () {
    const [sender, receiver] = provider.getWallets();

    const mockDependency = await deployMockContract(
      sender,
      SOME_DEPENDENCY.abi
    );

    const SomeDependency = await ethers.getContractFactory("SomeDependency");
    const Greeter = await ethers.getContractFactory("Greeter");
    const actualDependency = await SomeDependency.deploy();
    await actualDependency.deployed();

    await mockDependency.mock.getValue.returns(5);

    const greeter = await Greeter.deploy(
      "Hello, world!",
      mockDependency.address
    );

    await greeter.deployed();
    expect(await greeter.greet()).to.equal("Hello, world!");

    await greeter.setGreeting("Hola, mundo!");
    expect(await greeter.greet()).to.equal("Hola, mundo!");

    expect(await greeter.getValue()).to.equal(1);
  });
});
