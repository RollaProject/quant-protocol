import GnosisSafeL2Artifact from "@gnosis.pm/safe-contracts/build/artifacts/contracts/GnosisSafeL2.sol/GnosisSafeL2.json";
import GnosisSafeProxyFactoryArtifact from "@gnosis.pm/safe-contracts/build/artifacts/contracts/proxies/GnosisSafeProxyFactory.sol/GnosisSafeProxyFactory.json";
import { executeContractCallWithSigners } from "@gnosis.pm/safe-contracts/dist/utils/execution";
import { calculateProxyAddress } from "@gnosis.pm/safe-contracts/dist/utils/proxies";
import { Wallet } from "ethers";
import { ethers, upgrades } from "hardhat";
import { beforeEach, describe } from "mocha";
import { ConfigTimelockController, QuantConfig } from "../../../typechain";
import { expect, provider } from "../../setup";
import { revertToSnapshot, takeSnapshot } from "../../testUtils";
import { GnosisSafeL2 } from "./types";

const { AddressZero, Zero } = ethers.constants;

describe("GnosisSafeL2 integration tests", () => {
  let deployer: Wallet;
  let user1: Wallet;
  let user2: Wallet;
  let user3: Wallet;
  let gnosisSafeL2: GnosisSafeL2;
  let quantMultisig: GnosisSafeL2;
  let gnosisSafeProxyFactory;
  let owners: Array<string>;
  let configTimelockController: ConfigTimelockController;
  let quantConfig: QuantConfig;

  const confirmationThreshold = ethers.BigNumber.from("2"); // 2/3 confirmations/signatures required for a transaction
  const gnosisSafeVersion = "1.3.0";

  const aDay = 24 * 3600; // in seconds
  const timelockMinDelay = ethers.BigNumber.from(aDay);

  before(async () => {
    const signers = ([deployer, user1, user2, user3] = (
      await provider.getWallets()
    ).slice(0, 4));

    owners = signers.slice(1).map((signer) => signer.address);
  });

  beforeEach(async () => {
    const GnosisSafeL2 = new ethers.ContractFactory(
      GnosisSafeL2Artifact.abi,
      GnosisSafeL2Artifact.bytecode,
      deployer
    );

    // singleton to be used by the Proxy Factory to create a new Safe (multisig)
    gnosisSafeL2 = <GnosisSafeL2>await GnosisSafeL2.deploy();

    const GnosisSafeProxyFactory = new ethers.ContractFactory(
      GnosisSafeProxyFactoryArtifact.abi,
      GnosisSafeProxyFactoryArtifact.bytecode,
      deployer
    );

    gnosisSafeProxyFactory = await GnosisSafeProxyFactory.deploy();

    const saltNonce = ethers.BigNumber.from("133742999");
    const initCode = "0x";

    // calculate the address of the Safe once it gets deployed
    const proxyAddress = await calculateProxyAddress(
      gnosisSafeProxyFactory,
      gnosisSafeL2.address,
      initCode,
      saltNonce.toString()
    );

    await gnosisSafeProxyFactory.createProxyWithNonce(
      gnosisSafeL2.address,
      initCode,
      saltNonce
    );

    quantMultisig = gnosisSafeL2.attach(proxyAddress);

    // Initial Safe setup
    const to = AddressZero;
    const data = "0x";
    const fallbackHandler = AddressZero;
    const paymentToken = AddressZero; // ETH on L1, Matic on Polygon PoS side-chain
    const payment = Zero;
    const paymentReceiver = AddressZero;

    await quantMultisig.setup(
      owners,
      confirmationThreshold,
      to,
      data,
      fallbackHandler,
      paymentToken,
      payment,
      paymentReceiver
    );

    const ConfigTimelockControllerFactory = await ethers.getContractFactory(
      "ConfigTimelockController",
      deployer
    );

    const proposers = [quantMultisig.address, ...owners];
    const executors = [quantMultisig.address];
    configTimelockController = <ConfigTimelockController>(
      await ConfigTimelockControllerFactory.deploy(
        timelockMinDelay,
        proposers,
        executors
      )
    );

    const QuantConfigFactory = await ethers.getContractFactory(
      "QuantConfig",
      deployer
    );
    quantConfig = <QuantConfig>(
      await upgrades.deployProxy(QuantConfigFactory, [
        configTimelockController.address,
      ])
    );

    // Make the timelock the owner of QuantConfig
    await quantConfig
      .connect(deployer)
      .transferOwnership(configTimelockController.address);
  });

  it("Should create the Safe correctly", async () => {
    expect(await quantMultisig.VERSION()).to.equal(gnosisSafeVersion);
    expect(await quantMultisig.getOwners()).to.be.deep.equal(owners);
    expect(await quantMultisig.getThreshold()).to.equal(confirmationThreshold);
  });

  it("Should revert when the config deployer tries to set protocol values", async () => {
    await expect(
      quantConfig
        .connect(deployer)
        .setProtocolAddress(ethers.utils.id("priceRegistry"), user3.address)
    ).to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("Should revert when trying set a protocol variable in the config with insuficcient signatures", async () => {
    const priceRegistryVariable = ethers.utils.id("priceRegistry");
    const priceRegistryAddr = ethers.Wallet.createRandom().address;

    const snapshotId = await takeSnapshot();

    // extra 20 seconds to be enough until the block at which scheduleSetProtocolAddress is mined
    const eta = (await provider.getBlock("latest")).timestamp + aDay + 20;

    await configTimelockController
      .connect(user1)
      .scheduleSetProtocolAddress(
        priceRegistryVariable,
        priceRegistryAddr,
        quantConfig.address,
        eta
      );

    await provider.send("evm_mine", [eta]);

    await expect(
      executeContractCallWithSigners(
        quantMultisig,
        configTimelockController,
        "executeSetProtocolAddress",
        [priceRegistryVariable, priceRegistryAddr, quantConfig.address, eta],
        [user1]
      )
    ).to.be.revertedWith("revert GS020");

    revertToSnapshot(snapshotId);
  });

  it("The multisig (Safe) should be able to set a protocol variable in the config", async () => {
    const priceRegistryVariable = ethers.utils.id("priceRegistry");
    const priceRegistryAddr = ethers.Wallet.createRandom().address;

    const snapshotId = await takeSnapshot();

    // extra 20 seconds to be enough until the block at which scheduleSetProtocolAddress is mined
    const eta = (await provider.getBlock("latest")).timestamp + aDay + 20;

    await configTimelockController
      .connect(user1)
      .scheduleSetProtocolAddress(
        priceRegistryVariable,
        priceRegistryAddr,
        quantConfig.address,
        eta
      );

    expect(await quantConfig.protocolAddressesLength()).to.equal(0);
    expect(await quantConfig.protocolAddresses(priceRegistryVariable)).to.equal(
      AddressZero
    );

    await provider.send("evm_mine", [eta]);

    await executeContractCallWithSigners(
      quantMultisig,
      configTimelockController,
      "executeSetProtocolAddress",
      [priceRegistryVariable, priceRegistryAddr, quantConfig.address, eta],
      [user1, user2]
    );

    expect(await quantConfig.protocolAddressesLength()).to.equal(1);
    expect(await quantConfig.protocolAddresses(priceRegistryVariable)).to.equal(
      priceRegistryAddr
    );
    expect(await quantConfig.configuredProtocolAddresses(0)).to.equal(
      priceRegistryVariable
    );

    await revertToSnapshot(snapshotId);
  });
});
