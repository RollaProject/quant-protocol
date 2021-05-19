import { Signer } from "ethers";
import { ethers, upgrades } from "hardhat";
import { beforeEach, describe, it } from "mocha";
import { QuantConfig } from "../typechain/QuantConfig";
import { expect } from "./setup";

describe("QuantConfig", () => {
  let quantConfig: QuantConfig;
  let timelockController: Signer;
  let secondAccount: Signer;

  const protocolFee = ethers.utils.id("fee");

  beforeEach(async () => {
    [timelockController, secondAccount] = await ethers.getSigners();
    const QuantConfig = await ethers.getContractFactory("QuantConfig");
    quantConfig = <QuantConfig>(
      await upgrades.deployProxy(QuantConfig, [
        await timelockController.getAddress(),
      ])
    );
  });

  it("Should return the set TimelockController", async () => {
    expect(await quantConfig.timelockController()).to.equal(
      await timelockController.getAddress()
    );
  });

  it("Protocol fee should start as 0", async () => {
    expect(await quantConfig.protocolUints256(protocolFee)).to.equal(
      ethers.BigNumber.from("0")
    );
  });

  it("Admin should be able to set the protocol fee", async () => {
    await quantConfig
      .connect(timelockController)
      .setProtocolUint256(protocolFee, ethers.BigNumber.from("300"));
    expect(await quantConfig.protocolUints256(protocolFee)).to.equal(
      ethers.BigNumber.from("300")
    );
  });

  it("Should revert when a non-admin account tries to change the protocol fee", async () => {
    await expect(
      quantConfig
        .connect(secondAccount)
        .setProtocolUint256(protocolFee, ethers.BigNumber.from("100"))
    ).to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("Should maintain state across upgrades", async () => {
    await quantConfig
      .connect(timelockController)
      .setProtocolUint256(protocolFee, ethers.BigNumber.from("200"));
    const QuantConfigV2 = await ethers.getContractFactory("QuantConfigV2");
    quantConfig = <QuantConfig>(
      await upgrades.upgradeProxy(quantConfig.address, QuantConfigV2)
    );
    expect(await quantConfig.protocolUints256(protocolFee)).to.equal(
      ethers.BigNumber.from("200")
    );
  });

  it("Should be able to add new state variables through upgrades", async () => {
    const QuantConfigV2 = await ethers.getContractFactory("QuantConfigV2");
    quantConfig = <QuantConfig>(
      await upgrades.upgradeProxy(quantConfig.address, QuantConfigV2)
    );
    expect(await quantConfig.newV2StateVariable()).to.equal(
      ethers.BigNumber.from("0")
    );
  });
  it("Admin should still be able to set the protocol fee after an upgrade", async () => {
    const QuantConfigV2 = await ethers.getContractFactory("QuantConfigV2");
    quantConfig = <QuantConfig>(
      await upgrades.upgradeProxy(quantConfig.address, QuantConfigV2)
    );
    await quantConfig
      .connect(timelockController)
      .setProtocolUint256(protocolFee, ethers.BigNumber.from("400"));
    expect(await quantConfig.protocolUints256(protocolFee)).to.equal(
      ethers.BigNumber.from("400")
    );
  });
});
