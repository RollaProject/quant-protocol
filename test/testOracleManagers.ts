import { deployMockContract } from "@ethereum-waffle/mock-contract";
import { MockContract } from "ethereum-waffle";
import { Contract, ContractFactory, Signer } from "ethers";
import { ethers } from "hardhat";
import { beforeEach, describe, it } from "mocha";
import AGGREGATOR from "../artifacts/src/interfaces/external/chainlink/IEACAggregatorProxy.sol/IEACAggregatorProxy.json";
import ORACLE_REGISTRY from "../artifacts/src/pricing/OracleRegistry.sol/OracleRegistry.json";
import {
  ChainlinkFixedTimeOracleManager,
  ChainlinkOracleManager,
  MockAggregatorProxy,
  PriceRegistry,
} from "../typechain";
import { expect, provider } from "./setup";

export const testProviderOracleManager = async (
  testDescription: string,
  deployOracleManager: (
    priceRegistry: Contract,
    strikeAssetDecimals: number,
    fallBackPriceInSeconds: number
  ) => Promise<ChainlinkOracleManager | ChainlinkFixedTimeOracleManager>
): Promise<void> => {
  let priceRegistry: Contract;
  let owner: Signer;
  let normalUserAccount: Signer;
  let oracleManager: ChainlinkOracleManager | ChainlinkFixedTimeOracleManager;

  const assetOne = "0x0000000000000000000000000000000000000001";
  const assetTwo = "0x0000000000000000000000000000000000000002";
  const oracleOne = "0x0000000000000000000000000000000000000010";
  const oracleTwo = "0x0000000000000000000000000000000000000020";
  const oracleThree = "0x0000000000000000000000000000000000000030";

  const disputePeriod = 2 * 60 * 60; // 2 hours

  async function setUpTests() {
    [owner, normalUserAccount] = provider.getWallets();

    const mockOracleRegistry = await deployMockContract(
      owner,
      ORACLE_REGISTRY.abi
    );

    await mockOracleRegistry.mock.isOracleRegistered.returns(true);
    await mockOracleRegistry.mock.isOracleActive.returns(true);

    const PriceRegistry = await ethers.getContractFactory("PriceRegistry");

    priceRegistry = <PriceRegistry>(
      await PriceRegistry.deploy(6, disputePeriod, mockOracleRegistry.address)
    );

    oracleManager = await deployOracleManager(priceRegistry, 18, 0);
  }

  describe(`ProviderOracleManager - ${testDescription}`, function () {
    beforeEach(async function () {
      await setUpTests();
    });

    it("Should allow the addition of asset oracles, get number of assets and fetch prices", async function () {
      expect(await oracleManager.getAssetsLength()).to.be.equal(0);

      await expect(
        oracleManager.connect(owner).addAssetOracle(assetOne, oracleOne)
      )
        .to.emit(oracleManager, "OracleAdded")
        .withArgs(assetOne, oracleOne);

      expect(await oracleManager.getAssetsLength()).to.be.equal(1);

      await expect(
        oracleManager.connect(owner).addAssetOracle(assetTwo, oracleTwo)
      )
        .to.emit(oracleManager, "OracleAdded")
        .withArgs(assetTwo, oracleTwo);

      expect(await oracleManager.getAssetsLength()).to.be.equal(2);

      expect(await oracleManager.assets(0)).to.be.equal(assetOne);
      expect(await oracleManager.assets(1)).to.be.equal(assetTwo);
      expect(await oracleManager.getAssetOracle(assetOne)).to.be.equal(
        oracleOne
      );
      expect(await oracleManager.getAssetOracle(assetTwo)).to.be.equal(
        oracleTwo
      );
      await expect(
        oracleManager.connect(owner).addAssetOracle(assetTwo, oracleTwo)
      ).to.be.revertedWith(
        "ProviderOracleManager: Oracle already set for asset"
      );
      await expect(
        oracleManager.connect(owner).addAssetOracle(assetTwo, oracleThree)
      ).to.be.revertedWith(
        "ProviderOracleManager: Oracle already set for asset"
      );
    });

    it("Should not allow a non oracle manager account to add an asset", async function () {
      expect(await oracleManager.getAssetsLength()).to.be.equal(0);
      await expect(
        oracleManager
          .connect(normalUserAccount)
          .addAssetOracle(assetOne, oracleOne)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should revert when trying to add the zero address as an oracle", async () => {
      await expect(
        oracleManager
          .connect(owner)
          .addAssetOracle(assetOne, ethers.constants.AddressZero)
      ).to.be.revertedWith("ProviderOracleManager: Oracle is zero address");
    });
  });
};

export const testChainlinkOracleManager = async (
  testDescription: string,
  deployOracleManager: (
    priceRegistry: Contract,
    strikeAssetDecimals: number,
    fallBackPriceInSeconds: number
  ) => Promise<ChainlinkOracleManager | ChainlinkFixedTimeOracleManager>
): Promise<void> => {
  let MockAggregatorProxy: ContractFactory;
  let mockAggregatorProxy: MockAggregatorProxy;
  let PriceRegistry: ContractFactory;
  let priceRegistry: PriceRegistry;
  let mockAggregator: MockContract;
  let mockAggregatorTwo: MockContract;
  let mockOracleRegistry: MockContract;
  let owner: Signer;
  let normalUserAccount: Signer;
  let oracleManager: ChainlinkOracleManager | ChainlinkFixedTimeOracleManager;

  const assetOne = "0x0000000000000000000000000000000000000001";
  const assetTwo = "0x0000000000000000000000000000000000000002";

  const disputePeriod = 2 * 60 * 60; // 2 hours

  async function setUpTests() {
    [owner, normalUserAccount] = provider.getWallets();

    mockOracleRegistry = await deployMockContract(owner, ORACLE_REGISTRY.abi);

    await mockOracleRegistry.mock.isOracleRegistered.returns(true);
    await mockOracleRegistry.mock.isOracleActive.returns(true);

    PriceRegistry = await ethers.getContractFactory("PriceRegistry");

    priceRegistry = <PriceRegistry>(
      await PriceRegistry.deploy(18, disputePeriod, mockOracleRegistry.address)
    );

    oracleManager = await deployOracleManager(priceRegistry, 18, 0);

    mockAggregator = await deployMockContract(owner, AGGREGATOR.abi);
    await mockAggregator.mock.decimals.returns(8);
    mockAggregatorTwo = await deployMockContract(owner, AGGREGATOR.abi);
    await mockAggregatorTwo.mock.decimals.returns(8);

    MockAggregatorProxy = await ethers.getContractFactory(
      "MockAggregatorProxy"
    );

    mockAggregatorProxy = <MockAggregatorProxy>(
      await MockAggregatorProxy.deploy()
    );
  }

  describe(`ChainlinkOracleManager - ${testDescription}`, function () {
    beforeEach(async () => {
      await setUpTests();
    });
    it("Fallback method should allow a fallback submitter to submit only after the fallback period", async function () {
      //time in the past
      const expiryTimestamp = Math.round(Date.now() / 1000) - 100;
      const price = 5000;

      await expect(
        oracleManager
          .connect(owner)
          .addAssetOracle(assetOne, mockAggregator.address)
      )
        .to.emit(oracleManager, "OracleAdded")
        .withArgs(assetOne, mockAggregator.address);

      await expect(
        oracleManager
          .connect(owner)
          .setExpiryPriceInRegistryFallback(assetOne, expiryTimestamp, price)
      )
        .to.emit(oracleManager, "PriceRegistrySubmission")
        .withArgs(
          assetOne,
          expiryTimestamp,
          price,
          0,
          await owner.getAddress(),
          true
        );

      await expect(
        oracleManager
          .connect(owner)
          .setExpiryPriceInRegistryFallback(assetOne, expiryTimestamp, price)
      ).to.be.revertedWith(
        "PriceRegistry: Settlement price has already been set"
      );
    });

    it("Fallback method should not allow a fallback submitter to submit before the fallback period", async function () {
      const oracleManager = await deployOracleManager(priceRegistry, 18, 5000);
      await oracleManager.deployed();

      await oracleManager.addAssetOracle(assetOne, mockAggregator.address);

      await expect(
        oracleManager
          .connect(owner)
          .setExpiryPriceInRegistryFallback(
            assetOne,
            Math.round(Date.now() / 1000) + 3600,
            5000
          )
      ).to.be.revertedWith(
        "ChainlinkOracleManager: The fallback price period has not passed since the timestamp"
      );

      await expect(
        oracleManager
          .connect(normalUserAccount)
          .setExpiryPriceInRegistryFallback(assetOne, 10, 5000)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should fetch the current price of the asset provided correctly", async function () {
      await mockAggregator.mock.latestRoundData.returns(2, 0, 32, 32, 3);
      await mockAggregatorTwo.mock.latestRoundData.returns(
        2,
        ethers.utils.parseUnits("2", 8),
        32,
        32,
        3
      );

      await expect(
        oracleManager.getCurrentPrice(mockAggregator.address)
      ).to.be.revertedWith(
        "ProviderOracleManager: Oracle doesn't exist for that asset"
      );

      // await mockConfig.mock.hasRole.returns(true);

      await expect(
        oracleManager
          .connect(owner)
          .addAssetOracle(assetOne, mockAggregator.address)
      )
        .to.emit(oracleManager, "OracleAdded")
        .withArgs(assetOne, mockAggregator.address);

      await expect(
        oracleManager
          .connect(owner)
          .addAssetOracle(assetTwo, mockAggregatorTwo.address)
      )
        .to.emit(oracleManager, "OracleAdded")
        .withArgs(assetTwo, mockAggregatorTwo.address);

      await expect(oracleManager.getCurrentPrice(assetOne)).to.be.revertedWith(
        "ChainlinkOracleManager: No pricing data available"
      );

      expect(await oracleManager.getCurrentPrice(assetTwo)).to.be.equal(
        ethers.utils.parseUnits("2", 18)
      );
    });

    it("Should fail to fetch the round if the latest timestamp is equal to the expiry timestamp", async function () {
      // await mockConfig.mock.hasRole.returns(true);

      const expiryTimestamp = Math.round(Date.now() / 1000) - 100;

      await mockAggregatorProxy.setLatestTimestamp(expiryTimestamp);

      await oracleManager
        .connect(owner)
        .addAssetOracle(assetOne, mockAggregatorProxy.address);

      expect(
        oracleManager.searchRoundToSubmit(assetOne, expiryTimestamp)
      ).to.be.revertedWith(
        "ChainlinkOracleManager: The latest round timestamp is not after the expiry timestamp"
      );
    });

    it("Should not search if there is only 1 round of data", async function () {
      // await mockConfig.mock.hasRole.returns(true);

      const expiryTimestamp = Math.round(Date.now() / 1000) - 100;

      await mockAggregatorProxy.setLatestTimestamp(expiryTimestamp + 1);
      await mockAggregatorProxy.setLatestRoundData({
        roundId: 1,
        answer: 1,
        startedAt: 1,
        updatedAt: 1,
        answeredInRound: 1,
      });

      await oracleManager
        .connect(owner)
        .addAssetOracle(assetOne, mockAggregatorProxy.address);

      expect(
        oracleManager.searchRoundToSubmit(assetOne, expiryTimestamp)
      ).to.be.revertedWith(
        "ChainlinkOracleManager: Not enough rounds to find round after"
      );
    });
  });
};
