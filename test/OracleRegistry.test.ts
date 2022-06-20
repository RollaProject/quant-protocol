import { Signer } from "ethers";
import { ethers, waffle } from "hardhat";
import { beforeEach, describe, it } from "mocha";
import OracleRegistryJSON from "../artifacts/contracts/pricing/OracleRegistry.sol/OracleRegistry.json";
import { OracleRegistry } from "../typechain";
import { expect, provider } from "./setup";

const { deployContract } = waffle;

describe("OracleRegistry", () => {
  let oracleRegistry: OracleRegistry;
  let deployer: Signer;
  let secondAccount: Signer;
  const oracleOne = "0xc61Da13fef930E1Ef8DF714BDC3cED4d60D6204b";
  const oracleTwo = "0x6c99ebC5e73347585DDE7acDa5BA360a5Cf7e5eB";

  beforeEach(async () => {
    [deployer, secondAccount] = provider.getWallets();

    oracleRegistry = <OracleRegistry>(
      await deployContract(deployer, OracleRegistryJSON)
    );
  });

  it("Should allow multiple oracles to be added to the registry", async () => {
    expect(await oracleRegistry.getOraclesLength()).to.equal(0);

    await expect(oracleRegistry.getOracleId(oracleOne)).to.be.reverted;
    await expect(oracleRegistry.getOracleId(oracleTwo)).to.be.reverted;
    expect(await oracleRegistry.isOracleRegistered(oracleOne)).to.equal(false);
    expect(await oracleRegistry.isOracleRegistered(oracleTwo)).to.equal(false);

    await expect(oracleRegistry.connect(deployer).addOracle(oracleOne))
      .to.emit(oracleRegistry, "AddedOracle")
      .withArgs(ethers.utils.getAddress(oracleOne), ethers.BigNumber.from("1"));
    await expect(oracleRegistry.connect(deployer).addOracle(oracleTwo))
      .to.emit(oracleRegistry, "AddedOracle")
      .withArgs(ethers.utils.getAddress(oracleTwo), ethers.BigNumber.from("2"));
    expect(await oracleRegistry.getOraclesLength()).to.equal(2);
    expect(await oracleRegistry.getOracleId(oracleOne)).to.equal(1);
    expect(await oracleRegistry.getOracleId(oracleTwo)).to.equal(2);
    expect(await oracleRegistry.isOracleRegistered(oracleOne)).to.equal(true);
    expect(await oracleRegistry.isOracleRegistered(oracleTwo)).to.equal(true);
  });

  it("Oracle should be inactive by default and should be able to be activated and deactivated", async () => {
    await expect(oracleRegistry.getOracleId(oracleOne)).to.be.reverted;

    expect(await oracleRegistry.isOracleRegistered(oracleOne)).to.equal(false);

    await oracleRegistry.connect(deployer).addOracle(oracleOne);

    expect(await oracleRegistry.isOracleActive(oracleOne)).to.equal(false);

    await expect(oracleRegistry.connect(deployer).activateOracle(oracleOne))
      .to.emit(oracleRegistry, "ActivatedOracle")
      .withArgs(oracleOne);

    expect(await oracleRegistry.isOracleActive(oracleOne)).to.equal(true);

    await expect(
      await oracleRegistry.connect(deployer).deactivateOracle(oracleOne)
    )
      .to.emit(oracleRegistry, "DeactivatedOracle")
      .withArgs(oracleOne);

    expect(await oracleRegistry.isOracleActive(oracleOne)).to.equal(false);
  });

  it("Should not allow the same oracle to be added twice", async () => {
    await expect(await oracleRegistry.connect(deployer).addOracle(oracleOne))
      .to.emit(oracleRegistry, "AddedOracle")
      .withArgs(oracleOne, 1);

    await expect(
      oracleRegistry.connect(deployer).addOracle(oracleOne)
    ).to.be.revertedWith("OracleRegistry: Oracle already exists in registry");
  });

  it("Should not allow the same oracle to be activated or deactivated twice", async () => {
    await oracleRegistry.connect(deployer).addOracle(oracleOne);
    expect(
      await oracleRegistry.connect(deployer).isOracleActive(oracleOne)
    ).to.equal(false);
    await expect(
      oracleRegistry.connect(deployer).deactivateOracle(oracleOne)
    ).to.be.revertedWith("OracleRegistry: Oracle is already deactivated");

    await oracleRegistry.connect(deployer).activateOracle(oracleOne);

    expect(
      await oracleRegistry.connect(deployer).isOracleActive(oracleOne)
    ).to.equal(true);
    await expect(
      oracleRegistry.connect(deployer).activateOracle(oracleOne)
    ).to.be.revertedWith("OracleRegistry: Oracle is already activated");
  });

  it("Should not allow a non-admin to call restricted methods", async () => {
    await expect(
      oracleRegistry.connect(secondAccount).addOracle(oracleOne)
    ).to.be.revertedWith("Ownable: caller is not the owner");
    await expect(
      oracleRegistry.connect(secondAccount).activateOracle(oracleOne)
    ).to.be.revertedWith("Ownable: caller is not the owner");
    await expect(
      oracleRegistry.connect(secondAccount).deactivateOracle(oracleOne)
    ).to.be.revertedWith("Ownable: caller is not the owner");
  });
});
