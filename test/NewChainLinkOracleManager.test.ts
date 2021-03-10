import { deployMockContract } from "@ethereum-waffle/mock-contract";
import { MockContract } from "ethereum-waffle";
import { ContractFactory, Signer } from "ethers";
import { ethers } from "hardhat";
import { Address } from "hardhat-deploy/dist/types";
import { beforeEach, describe, it } from "mocha";
import AGGREGATOR from "../artifacts/contracts/external/chainlink/IEACAggregatorProxy.sol/IEACAggregatorProxy.json";
import PRICE_REGISTRY from "../artifacts/contracts/protocol/pricing/PriceRegistry.sol/PriceRegistry.json";
import CONFIG from "../artifacts/contracts/protocol/QuantConfig.sol/QuantConfig.json";
import { ChainlinkOracleManager } from "../typechain";
import { expect, provider } from "./setup";

describe("Greeter", function () {
  let ChainlinkOracleManager: ContractFactory;
  let chainlinkOracleManager: ChainlinkOracleManager;
  let mockConfig: MockContract;
  let mockAggregator: MockContract;
  let mockAggregatorTwo: MockContract;
  let mockPriceRegistry: MockContract;
  let owner: Signer;
  let oracleManagerAccount: Signer;
  let fallbackPriceAccount: Signer;
  let normalUserAccount: Signer;
  let oracleManagerAccountAddress: Address;
  let normalUserAccountAddress: Address;
  let fallbackPriceAccountAddress: Address;

  const assetOne = "0x0000000000000000000000000000000000000001";
  const assetTwo = "0x0000000000000000000000000000000000000002";
  const oracleOne = "0x0000000000000000000000000000000000000010";
  const oracleTwo = "0x0000000000000000000000000000000000000020";
  const oracleThree = "0x0000000000000000000000000000000000000030";
  const oracleManagerRole =
    "0xced6982f480260bdd8ad5cb18ff2854f0306d78d904ad6cc107e8f3a0f526c18";
  const fallbackPriceRole = ethers.utils
    .keccak256(ethers.utils.toUtf8Bytes("FALLBACK_PRICE_ROLE"))
    .toString();

  async function setUpTests() {
    [
      owner,
      oracleManagerAccount,
      normalUserAccount,
      fallbackPriceAccount,
    ] = provider.getWallets();

    mockConfig = await deployMockContract(owner, CONFIG.abi);
    mockAggregator = await deployMockContract(owner, AGGREGATOR.abi);
    mockAggregatorTwo = await deployMockContract(owner, AGGREGATOR.abi);
    mockPriceRegistry = await deployMockContract(owner, PRICE_REGISTRY.abi);

    await mockConfig.mock.ORACLE_MANAGER_ROLE.returns(oracleManagerRole);
    await mockConfig.mock.FALLBACK_PRICE_ROLE.returns(fallbackPriceRole);
    await mockConfig.mock.priceRegistry.returns(mockPriceRegistry.address);

    oracleManagerAccountAddress = await oracleManagerAccount.getAddress();
    normalUserAccountAddress = await normalUserAccount.getAddress();
    fallbackPriceAccountAddress = await fallbackPriceAccount.getAddress();

    //TODO (spiz): Couldn't get waffle working withArgs. Eventually we should move to this method of mocking
    /*
    await mockConfig.mock.hasRole
      .withArgs(oracleManagerRole, oracleManagerAccountAddress)
      .returns(true);

    await mockConfig.mock.hasRole
      .withArgs(oracleManagerRole, normalUserAccountAddress)
      .returns(false);

    await mockConfig.mock.hasRole
      .withArgs(oracleManagerRole, fallbackPriceAccountAddress)
      .returns(false);

    await mockConfig.mock.hasRole
      .withArgs(fallbackPriceRole, fallbackPriceAccountAddress)
      .returns(true);

    await mockConfig.mock.hasRole
      .withArgs(fallbackPriceRole, normalUserAccountAddress)
      .returns(false);

    await mockConfig.mock.hasRole
      .withArgs(oracleManagerRole, oracleManagerAccountAddress)
      .returns(false);
    */

    ChainlinkOracleManager = await ethers.getContractFactory(
      "ChainlinkOracleManager"
    );

    chainlinkOracleManager = <ChainlinkOracleManager>(
      await ChainlinkOracleManager.deploy(mockConfig.address, 0)
    );
  }

  beforeEach(async function () {
    await setUpTests();
  });

  //TODO (spiz): in future these should be externalised so they can be added to any implementation of ProviderOracleManager
  describe("ProviderOracleManager", function () {
    it("Should allow the addition of asset oracles, get number of assets and fetch prices", async function () {
      await mockConfig.mock.hasRole.returns(true);

      expect(await chainlinkOracleManager.getAssetsLength()).to.be.equal(0);

      await expect(
        chainlinkOracleManager
          .connect(oracleManagerAccount)
          .addAssetOracle(assetOne, oracleOne)
      )
        .to.emit(chainlinkOracleManager, "OracleAdded")
        .withArgs(assetOne, oracleOne);

      expect(await chainlinkOracleManager.getAssetsLength()).to.be.equal(1);

      await expect(
        chainlinkOracleManager
          .connect(oracleManagerAccount)
          .addAssetOracle(assetTwo, oracleTwo)
      )
        .to.emit(chainlinkOracleManager, "OracleAdded")
        .withArgs(assetTwo, oracleTwo);

      expect(await chainlinkOracleManager.getAssetsLength()).to.be.equal(2);

      expect(await chainlinkOracleManager.assets(0)).to.be.equal(assetOne);
      expect(await chainlinkOracleManager.assets(1)).to.be.equal(assetTwo);
      expect(await chainlinkOracleManager.assetOracles(assetOne)).to.be.equal(
        oracleOne
      );
      expect(await chainlinkOracleManager.assetOracles(assetTwo)).to.be.equal(
        oracleTwo
      );
      await expect(
        chainlinkOracleManager
          .connect(oracleManagerAccount)
          .addAssetOracle(assetTwo, oracleTwo)
      ).to.be.revertedWith("OracleManager: Oracle already set for asset");
      await expect(
        chainlinkOracleManager
          .connect(oracleManagerAccount)
          .addAssetOracle(assetTwo, oracleThree)
      ).to.be.revertedWith("OracleManager: Oracle already set for asset");
    });

    it("Should not allow a non oracle manager account to add an asset", async function () {
      await mockConfig.mock.hasRole.returns(false);

      expect(await chainlinkOracleManager.getAssetsLength()).to.be.equal(0);
      await expect(
        chainlinkOracleManager
          .connect(normalUserAccount)
          .addAssetOracle(assetOne, oracleOne)
      ).to.be.revertedWith(
        "OracleManager: Only an oracle admin can add an oracle"
      );
    });
  });

  describe("Pricing", function () {
    it("Fallback method should allow a fallback submitter to submit only after the fallback period", async function () {
      //time in the past
      const expiryTimestamp = Math.round(Date.now() / 1000) - 100;
      const price = 5000;

      await mockConfig.mock.hasRole.returns(true);

      await expect(
        chainlinkOracleManager
          .connect(oracleManagerAccount)
          .addAssetOracle(assetOne, oracleOne)
      )
        .to.emit(chainlinkOracleManager, "OracleAdded")
        .withArgs(assetOne, oracleOne);

      await mockConfig.mock.priceRegistry.returns(mockPriceRegistry.address);
      await mockPriceRegistry.mock.setSettlementPrice.returns();

      await expect(
        chainlinkOracleManager
          .connect(fallbackPriceAccount)
          .setExpiryPriceInRegistryFallback(assetOne, expiryTimestamp, price)
      )
        .to.emit(chainlinkOracleManager, "PriceRegistrySubmission")
        .withArgs(assetOne, expiryTimestamp, price, 0, oracleOne, true);

      //TODO (spiz): not supported by hardhat waffle. Uncomment when hardhat adds support
      //TODO (spiz): track here: https://github.com/nomiclabs/hardhat/issues/1135
      /*
      expect("setSettlementPrice").to.be.calledOnContractWith(
        mockPriceRegistry,
        [assetOne, expiryTimestamp, price]
      );
      */

      await mockPriceRegistry.mock.setSettlementPrice.revertsWithReason(
        "PriceRegistry: Settlement price has already been set"
      );

      await expect(
        chainlinkOracleManager
          .connect(fallbackPriceAccount)
          .setExpiryPriceInRegistryFallback(assetOne, expiryTimestamp, price)
      ).to.be.revertedWith(
        "PriceRegistry: Settlement price has already been set"
      );
    });

    it("Fallback method should not allow a fallback submitter to submit before the fallback period", async function () {
      chainlinkOracleManager = <ChainlinkOracleManager>(
        await ChainlinkOracleManager.deploy(mockConfig.address, 500)
      );
      await chainlinkOracleManager.deployed();

      await mockConfig.mock.hasRole.returns(true);

      await chainlinkOracleManager.addAssetOracle(assetOne, oracleOne);

      await expect(
        chainlinkOracleManager
          .connect(fallbackPriceAccount)
          .setExpiryPriceInRegistryFallback(
            assetOne,
            Math.round(Date.now() / 1000),
            5000
          )
      ).to.be.revertedWith(
        "ChainlinkOracleManager: The fallback price period has not passed since the timestamp"
      );

      await mockConfig.mock.hasRole.returns(false);

      await expect(
        chainlinkOracleManager
          .connect(normalUserAccount)
          .setExpiryPriceInRegistryFallback(assetOne, 10, 5000)
      ).to.be.revertedWith(
        "ChainlinkOracleManager: Only the fallback price submitter can submit a fallback price"
      );
    });

    it("Should fetch the current price of the asset provided correctly", async function () {
      await mockAggregator.mock.latestAnswer.returns(0);
      await mockAggregatorTwo.mock.latestAnswer.returns(2);

      await expect(
        chainlinkOracleManager.getCurrentPrice(mockAggregator.address)
      ).to.be.revertedWith("ChainlinkOracleManager: Asset not supported");

      await mockConfig.mock.hasRole.returns(true);

      await expect(
        chainlinkOracleManager
          .connect(oracleManagerAccount)
          .addAssetOracle(assetOne, mockAggregator.address)
      )
        .to.emit(chainlinkOracleManager, "OracleAdded")
        .withArgs(assetOne, mockAggregator.address);

      await expect(
        chainlinkOracleManager
          .connect(oracleManagerAccount)
          .addAssetOracle(assetTwo, mockAggregatorTwo.address)
      )
        .to.emit(chainlinkOracleManager, "OracleAdded")
        .withArgs(assetTwo, mockAggregatorTwo.address);

      await expect(
        chainlinkOracleManager.getCurrentPrice(assetOne)
      ).to.be.revertedWith("ChainlinkOracleManager: No pricing data available");

      expect(
        await chainlinkOracleManager.getCurrentPrice(assetTwo)
      ).to.be.equal(2);
    });
  });

  /*
  it("random test", async function () {
    await expect(
      chainlinkOracleManager.setExpiryPriceInRegistryFallback(
        assetOne,
        Math.round(Date.now() / 1000) - 10,
        123
      )
    ).to.emit(chainlinkOracleManager, "PriceRegistrySubmission");
  });
  */
});
