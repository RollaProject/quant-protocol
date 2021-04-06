import { ContractFactory, Signer } from "ethers";
import { ethers, upgrades, waffle } from "hardhat";
import { beforeEach, describe, it } from "mocha";
import PriceRegistryJSON from "../artifacts/contracts/protocol/pricing/PriceRegistry.sol/PriceRegistry.json";
import { PriceRegistry, QuantConfig } from "../typechain";
import { expect, provider } from "./setup";

const { deployContract } = waffle;

describe("PriceRegistry", () => {
  let quantConfig: QuantConfig;
  let priceRegistry: PriceRegistry;
  let admin: Signer;
  let secondAccount: Signer;
  let oracle: string;
  const assetOne = "0x000000000000000000000000000000000000000B";

  beforeEach(async () => {
    [admin, secondAccount] = provider.getWallets();
    const QuantConfig: ContractFactory = await ethers.getContractFactory(
      "QuantConfig"
    );
    quantConfig = <QuantConfig>(
      await upgrades.deployProxy(QuantConfig, [await admin.getAddress()])
    );
    priceRegistry = <PriceRegistry>(
      await deployContract(admin, PriceRegistryJSON, [quantConfig.address])
    );
    oracle = await admin.getAddress(); //this is the oracle since its the price submitter

    await quantConfig.grantRole(
      await quantConfig.PRICE_SUBMITTER_ROLE(),
      await admin.getAddress()
    );
  });

  it("Should allow a price to be set only once", async () => {
    const timestamp = 1;
    const price = 10;

    expect(
      priceRegistry.getSettlementPrice(oracle, assetOne, timestamp)
    ).to.be.revertedWith("PriceRegistry: No settlement price has been set");
    expect(
      await priceRegistry.hasSettlementPrice(oracle, assetOne, timestamp)
    ).to.equal(false);

    await priceRegistry
      .connect(admin)
      .setSettlementPrice(assetOne, timestamp, price);

    expect(
      await priceRegistry.getSettlementPrice(oracle, assetOne, timestamp)
    ).to.equal(10);
    expect(
      await priceRegistry.hasSettlementPrice(oracle, assetOne, timestamp)
    ).to.equal(true);
    expect(
      priceRegistry.connect(admin).setSettlementPrice(assetOne, timestamp, 40)
    ).to.be.revertedWith(
      "PriceRegistry: Settlement price has already been set"
    );
  });

  it("Should not allow a price to be set for a future timestamp", async () => {
    await expect(
      priceRegistry
        .connect(admin)
        .setSettlementPrice(
          assetOne,
          Math.round(Date.now() / 1000) + 100000,
          40
        )
    ).to.be.revertedWith(
      "PriceRegistry: Can't set a price for a time in the future"
    );
  });

  it("Should not allow a non-admin to call restricted methods", async () => {
    await expect(
      priceRegistry.connect(secondAccount).setSettlementPrice(assetOne, 1, 40)
    ).to.be.revertedWith("PriceRegistry: Price submitter is not an oracle");
  });
});
