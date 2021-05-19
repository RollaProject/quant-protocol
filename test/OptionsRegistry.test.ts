import { MockContract } from "ethereum-waffle";
import { Signer } from "ethers";
import { waffle } from "hardhat";
import { beforeEach, describe, it } from "mocha";
import QTokenJSON from "../artifacts/contracts/options/QToken.sol/QToken.json";
import OptionsRegistryJSON from "../artifacts/contracts/periphery/OptionsRegistry.sol/OptionsRegistry.json";
import { OptionsRegistry } from "../typechain";
import { expect, provider } from "./setup";

const { deployContract, deployMockContract } = waffle;

describe("OptionsRegistry", () => {
  let optionsRegistry: OptionsRegistry;
  let qToken: MockContract;
  let qTokenTwo: MockContract;
  let admin: Signer;
  let secondAccount: Signer;
  const mockUnderlyingAsset = "0x000000000000000000000000000000000000000A";

  beforeEach(async () => {
    [admin, secondAccount] = provider.getWallets();

    optionsRegistry = <OptionsRegistry>(
      await deployContract(admin, OptionsRegistryJSON, [admin.getAddress()])
    );
    qToken = await deployMockContract(admin, QTokenJSON.abi);
    qTokenTwo = await deployMockContract(admin, QTokenJSON.abi);
  });

  it("Should allow adding of options", async () => {
    await qToken.mock.underlyingAsset.returns(mockUnderlyingAsset);
    await qTokenTwo.mock.underlyingAsset.returns(mockUnderlyingAsset);

    //check no underlyings to begin with
    expect(await optionsRegistry.numberOfUnderlyingAssets()).to.equal(0);
    expect(
      await optionsRegistry.numberOfOptionsForUnderlying(mockUnderlyingAsset)
    ).to.equal(0);

    await optionsRegistry.connect(admin).addOption(qToken.address);

    //check there's an underlying now
    expect(await optionsRegistry.numberOfUnderlyingAssets()).to.equal(1);
    expect(
      (await optionsRegistry.getOptionDetails(mockUnderlyingAsset, 0))[0]
    ).to.equal(qToken.address);

    await optionsRegistry.connect(admin).addOption(qTokenTwo.address);

    expect(await optionsRegistry.numberOfUnderlyingAssets()).to.equal(1);
    expect(
      await optionsRegistry.numberOfOptionsForUnderlying(mockUnderlyingAsset)
    ).to.equal(2);
    expect(
      (await optionsRegistry.getOptionDetails(mockUnderlyingAsset, 1))[0]
    ).to.equal(qTokenTwo.address);
  });

  it("Should allow the non-default admin to call restricted methods when granted role", async () => {
    await qToken.mock.underlyingAsset.returns(mockUnderlyingAsset);

    await optionsRegistry
      .connect(admin)
      .grantRole(
        await optionsRegistry.OPTION_MANAGER_ROLE(),
        await secondAccount.getAddress()
      );

    expect(
      await optionsRegistry.connect(secondAccount).numberOfUnderlyingAssets()
    ).to.equal(0);

    await optionsRegistry.connect(secondAccount).addOption(qToken.address);

    expect(
      await optionsRegistry.connect(secondAccount).numberOfUnderlyingAssets()
    ).to.equal(1);

    expect(
      await (
        await optionsRegistry.getOptionDetails(mockUnderlyingAsset, 0)
      )[1]
    ).to.equal(false);

    await optionsRegistry
      .connect(secondAccount)
      .makeOptionVisible(qToken.address, 0);

    expect(
      await (
        await optionsRegistry.getOptionDetails(mockUnderlyingAsset, 0)
      )[1]
    ).to.equal(true);

    await optionsRegistry
      .connect(secondAccount)
      .makeOptionInvisible(qToken.address, 0);

    expect(
      await (
        await optionsRegistry.getOptionDetails(mockUnderlyingAsset, 0)
      )[1]
    ).to.equal(false);
  });

  it("Should not allow a non-admin to call restricted methods", async () => {
    await expect(
      optionsRegistry
        .connect(secondAccount)
        .addOption("0x0000000000000000000000000000000000000000")
    ).to.be.revertedWith(
      "OptionsRegistry: Only an option manager can add an option"
    );
    await expect(
      optionsRegistry
        .connect(secondAccount)
        .makeOptionVisible("0x0000000000000000000000000000000000000000", 1)
    ).to.be.revertedWith(
      "OptionsRegistry: Only an option manager can change visibility of an option"
    );
    await expect(
      optionsRegistry
        .connect(secondAccount)
        .makeOptionInvisible("0x0000000000000000000000000000000000000000", 1)
    ).to.be.revertedWith(
      "OptionsRegistry: Only an option manager can change visibility of an option"
    );
  });
});
