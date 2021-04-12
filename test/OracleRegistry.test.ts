import { Signer } from "ethers";
import { ethers, waffle } from "hardhat";
import { beforeEach, describe, it } from "mocha";
import OracleProviderRegistryJSON from "../artifacts/contracts/protocol/pricing/OracleRegistry.sol/OracleRegistry.json";
import { OracleRegistry, QuantConfig } from "../typechain";
import { expect, provider } from "./setup";
import { deployQuantConfig } from "./testUtils";

const { deployContract } = waffle;

describe("OracleRegistry", () => {
  let quantConfig: QuantConfig;
  let oracleProviderRegistry: OracleRegistry;
  let timelockController: Signer;
  let secondAccount: Signer;
  let oracleManager: Signer;
  let userAddress: string;
  const oracleOne = "0x000000000000000000000000000000000000000A";
  const oracleTwo = "0x000000000000000000000000000000000000000B";

  beforeEach(async () => {
    [timelockController, secondAccount, oracleManager] = provider.getWallets();
    userAddress = await secondAccount.getAddress();

    quantConfig = await deployQuantConfig(timelockController, [
      {
        addresses: [await oracleManager.getAddress()],
        role: ethers.utils.id("ORACLE_MANAGER_ROLE"),
      },
    ]);

    oracleProviderRegistry = <OracleRegistry>(
      await deployContract(timelockController, OracleProviderRegistryJSON, [
        quantConfig.address,
      ])
    );

    await quantConfig
      .connect(timelockController)
      .setRoleAdmin(
        ethers.utils.id("PRICE_SUBMITTER_ROLE"),
        ethers.utils.id("PRICE_SUBMITTER_ROLE_ADMIN")
      );

    await quantConfig
      .connect(timelockController)
      .grantRole(
        ethers.utils.id("PRICE_SUBMITTER_ROLE_ADMIN"),
        await oracleProviderRegistry.address
      );
  });

  it("Should allow multiple oracles to be added to the registry", async () => {
    expect(await oracleProviderRegistry.getOraclesLength()).to.equal(0);

    await expect(
      oracleProviderRegistry.getOracleId(oracleOne)
    ).to.be.revertedWith("OracleRegistry: Oracle doesn't exist in registry");
    await expect(
      oracleProviderRegistry.getOracleId(oracleTwo)
    ).to.be.revertedWith("OracleRegistry: Oracle doesn't exist in registry");
    expect(await oracleProviderRegistry.isOracleRegistered(oracleOne)).to.equal(
      false
    );
    expect(await oracleProviderRegistry.isOracleRegistered(oracleTwo)).to.equal(
      false
    );

    await oracleProviderRegistry.connect(oracleManager).addOracle(oracleOne);
    await oracleProviderRegistry.connect(oracleManager).addOracle(oracleTwo);
    expect(await oracleProviderRegistry.getOraclesLength()).to.equal(2);
    expect(await oracleProviderRegistry.getOracleId(oracleOne)).to.equal(1);
    expect(await oracleProviderRegistry.getOracleId(oracleTwo)).to.equal(2);
    expect(await oracleProviderRegistry.isOracleRegistered(oracleOne)).to.equal(
      true
    );
    expect(await oracleProviderRegistry.isOracleRegistered(oracleTwo)).to.equal(
      true
    );
  });

  it("Oracle should be inactive by default and should be able to be activated and deactivated", async () => {
    await expect(
      oracleProviderRegistry.getOracleId(oracleOne)
    ).to.be.revertedWith("OracleRegistry: Oracle doesn't exist in registry");

    expect(await oracleProviderRegistry.isOracleRegistered(oracleOne)).to.equal(
      false
    );

    await oracleProviderRegistry.connect(oracleManager).addOracle(oracleOne);

    expect(await oracleProviderRegistry.isOracleActive(oracleOne)).to.equal(
      false
    );

    await expect(
      oracleProviderRegistry.connect(oracleManager).activateOracle(oracleOne)
    )
      .to.emit(oracleProviderRegistry, "ActivatedOracle")
      .withArgs(oracleOne);

    expect(await oracleProviderRegistry.isOracleActive(oracleOne)).to.equal(
      true
    );

    await expect(
      await oracleProviderRegistry
        .connect(oracleManager)
        .deactivateOracle(oracleOne)
    )
      .to.emit(oracleProviderRegistry, "DeactivatedOracle")
      .withArgs(oracleOne);

    expect(await oracleProviderRegistry.isOracleActive(oracleOne)).to.equal(
      false
    );
  });

  it("Should not allow the same oracle to be added twice", async () => {
    await expect(
      await oracleProviderRegistry.connect(oracleManager).addOracle(oracleOne)
    )
      .to.emit(oracleProviderRegistry, "AddedOracle")
      .withArgs(oracleOne, 1);

    await expect(
      oracleProviderRegistry.connect(oracleManager).addOracle(oracleOne)
    ).to.be.revertedWith("OracleRegistry: Oracle already exists in registry");
  });

  it("Should not allow the same oracle to be activated or deactivated twice", async () => {
    await oracleProviderRegistry.connect(oracleManager).addOracle(oracleOne);
    expect(
      await oracleProviderRegistry
        .connect(oracleManager)
        .isOracleActive(oracleOne)
    ).to.equal(false);
    await expect(
      oracleProviderRegistry.connect(oracleManager).deactivateOracle(oracleOne)
    ).to.be.revertedWith("OracleRegistry: Oracle is already deactivated");

    await oracleProviderRegistry
      .connect(oracleManager)
      .activateOracle(oracleOne);

    expect(
      await oracleProviderRegistry
        .connect(oracleManager)
        .isOracleActive(oracleOne)
    ).to.equal(true);
    await expect(
      oracleProviderRegistry.connect(oracleManager).activateOracle(oracleOne)
    ).to.be.revertedWith("OracleRegistry: Oracle is already activated");
  });

  it("Should not allow a non-admin to call restricted methods", async () => {
    await expect(
      oracleProviderRegistry.connect(secondAccount).addOracle(oracleOne)
    ).to.be.revertedWith(
      "OracleRegistry: Only an oracle admin can add an oracle"
    );
    await expect(
      oracleProviderRegistry.connect(secondAccount).activateOracle(oracleOne)
    ).to.be.revertedWith(
      "OracleRegistry: Only an oracle admin can add an oracle"
    );
    await expect(
      oracleProviderRegistry.connect(secondAccount).deactivateOracle(oracleOne)
    ).to.be.revertedWith(
      "OracleRegistry: Only an oracle admin can add an oracle"
    );
  });
});
