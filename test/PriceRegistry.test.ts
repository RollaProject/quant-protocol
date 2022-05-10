import { deployMockContract } from "ethereum-waffle";
import { Signer } from "ethers";
import { ethers, waffle } from "hardhat";
import { beforeEach, describe, it } from "mocha";
import OracleRegistryJSON from "../artifacts/contracts/pricing/OracleRegistry.sol/OracleRegistry.json";
import PriceRegistryJSON from "../artifacts/contracts/pricing/PriceRegistry.sol/PriceRegistry.json";
import { PriceRegistry } from "../typechain";
import { expect, provider } from "./setup";

const { deployContract } = waffle;

describe("PriceRegistry", () => {
  let priceRegistry: PriceRegistry;
  let admin: Signer;
  let secondAccount: Signer;
  let oracle: string;
  const assetOne = "0x000000000000000000000000000000000000000b";
  const strikeAssetDecimals = 18;

  beforeEach(async () => {
    [admin, secondAccount] = provider.getWallets();

    const mockOracleRegistry = await deployMockContract(
      admin,
      OracleRegistryJSON.abi
    );

    await mockOracleRegistry.mock.isOracleRegistered
      .withArgs(await admin.getAddress())
      .returns(true);
    await mockOracleRegistry.mock.isOracleActive
      .withArgs(await admin.getAddress())
      .returns(true);

    await mockOracleRegistry.mock.isOracleRegistered
      .withArgs(await secondAccount.getAddress())
      .returns(false);
    await mockOracleRegistry.mock.isOracleActive
      .withArgs(await secondAccount.getAddress())
      .returns(false);

    priceRegistry = <PriceRegistry>(
      await deployContract(admin, PriceRegistryJSON, [
        strikeAssetDecimals,
        mockOracleRegistry.address,
      ])
    );
    oracle = await admin.getAddress(); //this is the oracle since its the price submitter
  });

  it("Should allow a price to be set only once", async () => {
    const timestamp = 1;
    const price = ethers.utils.parseUnits("10", strikeAssetDecimals);

    expect(
      priceRegistry.getSettlementPrice(oracle, timestamp, assetOne)
    ).to.be.revertedWith("PriceRegistry: No settlement price has been set");
    expect(
      await priceRegistry.hasSettlementPrice(oracle, timestamp, assetOne)
    ).to.equal(false);

    expect(
      await priceRegistry
        .connect(admin)
        .setSettlementPrice(assetOne, timestamp, strikeAssetDecimals, price)
    )
      .to.emit(priceRegistry, "PriceStored")
      .withArgs(
        await admin.getAddress(),
        assetOne,
        timestamp,
        strikeAssetDecimals,
        price
      );

    expect(
      await priceRegistry.getSettlementPrice(oracle, timestamp, assetOne)
    ).to.equal(price);
    expect(
      await priceRegistry.hasSettlementPrice(oracle, timestamp, assetOne)
    ).to.equal(true);
    expect(
      priceRegistry
        .connect(admin)
        .setSettlementPrice(assetOne, timestamp, strikeAssetDecimals, 40)
    ).to.be.revertedWith(
      "PriceRegistry: Settlement price has already been set"
    );
  });

  it("Should return the correct values when a price with less than 18 decimals is set", async () => {
    const timestamp = 1;
    const price = ethers.utils.parseUnits("10", 2);

    expect(
      priceRegistry.getSettlementPrice(oracle, timestamp, assetOne)
    ).to.be.revertedWith("PriceRegistry: No settlement price has been set");
    expect(
      await priceRegistry.hasSettlementPrice(oracle, timestamp, assetOne)
    ).to.equal(false);

    await priceRegistry
      .connect(admin)
      .setSettlementPrice(assetOne, timestamp, 2, price);

    expect(
      await priceRegistry.getSettlementPrice(oracle, timestamp, assetOne)
    ).to.equal(ethers.utils.parseUnits("10", strikeAssetDecimals));
  });

  it("Should return the correct values when a price with more than 18 decimals is set", async () => {
    const timestamp = 1;
    const price = ethers.utils.parseUnits("10", 24);

    expect(
      priceRegistry.getSettlementPrice(oracle, timestamp, assetOne)
    ).to.be.revertedWith("PriceRegistry: No settlement price has been set");
    expect(
      await priceRegistry.hasSettlementPrice(oracle, timestamp, assetOne)
    ).to.equal(false);

    await priceRegistry
      .connect(admin)
      .setSettlementPrice(assetOne, timestamp, 24, price);

    expect(
      await priceRegistry.getSettlementPrice(oracle, timestamp, assetOne)
    ).to.equal(ethers.utils.parseUnits("10", strikeAssetDecimals));
  });

  it("Should not allow a price to be set for a future timestamp", async () => {
    await expect(
      priceRegistry
        .connect(admin)
        .setSettlementPrice(
          assetOne,
          Math.round(Date.now() / 1000) + 100000,
          strikeAssetDecimals,
          40
        )
    ).to.be.revertedWith(
      "PriceRegistry: Can't set a price for a time in the future"
    );
  });

  it("Should not allow a non-admin to call restricted methods", async () => {
    await expect(
      priceRegistry
        .connect(secondAccount)
        .setSettlementPrice(assetOne, 1, strikeAssetDecimals, 40)
    ).to.be.revertedWith(
      "PriceRegistry: Price submitter is not an active oracle"
    );
  });
});
