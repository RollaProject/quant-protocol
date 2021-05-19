import { deployMockContract } from "@ethereum-waffle/mock-contract";
import { MockContract } from "ethereum-waffle";
import { ContractFactory, Signer } from "ethers";
import { ethers } from "hardhat";
import { Address } from "hardhat-deploy/dist/types";
import { beforeEach, describe, it } from "mocha";
import AGGREGATOR from "../artifacts/contracts/external/chainlink/IEACAggregatorProxy.sol/IEACAggregatorProxy.json";
import PRICE_REGISTRY from "../artifacts/contracts/pricing/PriceRegistry.sol/PriceRegistry.json";
import CONFIG from "../artifacts/contracts/QuantConfig.sol/QuantConfig.json";
import {
  ChainlinkOracleManager,
  MockAggregatorProxy,
  PriceRegistry,
} from "../typechain";
import { expect, provider } from "./setup";

describe("ChainlinkOracleManager", function () {
  let ChainlinkOracleManager: ContractFactory;
  let chainlinkOracleManager: ChainlinkOracleManager;
  let MockAggregatorProxy: ContractFactory;
  let mockAggregatorProxy: MockAggregatorProxy;
  let PriceRegistry: ContractFactory;
  let priceRegistry: PriceRegistry;
  let mockConfig: MockContract;
  let mockAggregator: MockContract;
  let mockAggregatorTwo: MockContract;
  let mockPriceRegistry: MockContract;
  let owner: Signer;
  let oracleManagerAccount: Signer;
  let fallbackPriceAccount: Signer;
  let normalUserAccount: Signer;
  let normalUserAccountAddress: Address;
  let fallbackPriceAccountAddress: Address;

  const assetOne = "0x0000000000000000000000000000000000000001";
  const assetTwo = "0x0000000000000000000000000000000000000002";
  const oracleOne = "0x0000000000000000000000000000000000000010";
  const oracleTwo = "0x0000000000000000000000000000000000000020";
  const oracleThree = "0x0000000000000000000000000000000000000030";

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

    // await mockConfig.mock.protocolAddresses.withArgs("ora")
    await mockConfig.mock.quantRoles
      .withArgs("ORACLE_MANAGER_ROLE")
      .returns(ethers.utils.id("ORACLE_MANAGER_ROLE"));
    await mockConfig.mock.quantRoles
      .withArgs("FALLBACK_PRICE_ROLE")
      .returns(ethers.utils.id("FALLBACK_PRICE_ROLE"));
    await mockConfig.mock.quantRoles
      .withArgs("PRICE_SUBMITTER_ROLE")
      .returns(ethers.utils.id("PRICE_SUBMITTER_ROLE"));

    await mockConfig.mock.protocolAddresses
      .withArgs(ethers.utils.id("priceRegistry"))
      .returns(mockPriceRegistry.address);

    normalUserAccountAddress = await normalUserAccount.getAddress();
    fallbackPriceAccountAddress = await fallbackPriceAccount.getAddress();

    //TODO (quantizations): Couldn't get waffle working withArgs. Eventually we should move to this method of mocking
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

    MockAggregatorProxy = await ethers.getContractFactory(
      "MockAggregatorProxy"
    );

    mockAggregatorProxy = <MockAggregatorProxy>(
      await MockAggregatorProxy.deploy()
    );

    PriceRegistry = await ethers.getContractFactory("PriceRegistry");

    priceRegistry = <PriceRegistry>(
      await PriceRegistry.deploy(mockConfig.address)
    );
  }

  beforeEach(async function () {
    await setUpTests();
  });

  //TODO (quantizations): in future these should be externalised so they can be added to any implementation of ProviderOracleManager
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
      expect(await chainlinkOracleManager.getAssetOracle(assetOne)).to.be.equal(
        oracleOne
      );
      expect(await chainlinkOracleManager.getAssetOracle(assetTwo)).to.be.equal(
        oracleTwo
      );
      await expect(
        chainlinkOracleManager
          .connect(oracleManagerAccount)
          .addAssetOracle(assetTwo, oracleTwo)
      ).to.be.revertedWith(
        "ProviderOracleManager: Oracle already set for asset"
      );
      await expect(
        chainlinkOracleManager
          .connect(oracleManagerAccount)
          .addAssetOracle(assetTwo, oracleThree)
      ).to.be.revertedWith(
        "ProviderOracleManager: Oracle already set for asset"
      );
    });

    it("Should not allow a non oracle manager account to add an asset", async function () {
      await mockConfig.mock.hasRole.returns(false);

      expect(await chainlinkOracleManager.getAssetsLength()).to.be.equal(0);
      await expect(
        chainlinkOracleManager
          .connect(normalUserAccount)
          .addAssetOracle(assetOne, oracleOne)
      ).to.be.revertedWith(
        "ProviderOracleManager: Only an oracle admin can add an oracle"
      );
    });
  });

  describe("ChainlinkOracleManager", function () {
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

      await mockConfig.mock.protocolAddresses
        .withArgs(ethers.utils.id("priceRegistry"))
        .returns(mockPriceRegistry.address);
      // await mockConfig.mock.priceRegistry.returns(mockPriceRegistry.address);
      await mockPriceRegistry.mock.setSettlementPrice.returns();

      await expect(
        chainlinkOracleManager
          .connect(fallbackPriceAccount)
          .setExpiryPriceInRegistryFallback(assetOne, expiryTimestamp, price)
      )
        .to.emit(chainlinkOracleManager, "PriceRegistrySubmission")
        .withArgs(
          assetOne,
          expiryTimestamp,
          price,
          0,
          fallbackPriceAccountAddress,
          true
        );

      //TODO (quantizations): not supported by hardhat waffle. Uncomment when hardhat adds support
      //TODO (quantizations): track here: https://github.com/nomiclabs/hardhat/issues/1135
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
      ).to.be.revertedWith(
        "ProviderOracleManager: Oracle doesn't exist for that asset"
      );

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

    it("Should fail to fetch the round if the latest timestamp is equal to the expiry timestamp", async function () {
      await mockConfig.mock.hasRole.returns(true);

      const expiryTimestamp = Math.round(Date.now() / 1000) - 100;

      await mockAggregatorProxy.setLatestTimestamp(expiryTimestamp);

      await chainlinkOracleManager
        .connect(oracleManagerAccount)
        .addAssetOracle(assetOne, mockAggregatorProxy.address);

      expect(
        chainlinkOracleManager.searchRoundToSubmit(assetOne, expiryTimestamp)
      ).to.be.revertedWith(
        "ChainlinkOracleManager: The latest round timestamp is not after the expiry timestamp"
      );
    });

    it("Should not search if there is only 1 round of data", async function () {
      await mockConfig.mock.hasRole.returns(true);

      const expiryTimestamp = Math.round(Date.now() / 1000) - 100;

      await mockAggregatorProxy.setLatestTimestamp(expiryTimestamp + 1);
      await mockAggregatorProxy.setLatestRoundData({
        roundId: 1,
        answer: 1,
        startedAt: 1,
        updatedAt: 1,
        answeredInRound: 1,
      });

      await chainlinkOracleManager
        .connect(oracleManagerAccount)
        .addAssetOracle(assetOne, mockAggregatorProxy.address);

      expect(
        chainlinkOracleManager.searchRoundToSubmit(assetOne, expiryTimestamp)
      ).to.be.revertedWith(
        "ChainlinkOracleManager: Not enough rounds to find round after"
      );
    });

    const setUpTestWithMockAggregator = async () => {
      await mockConfig.mock.hasRole.returns(true);

      await mockAggregatorProxy.setLatestTimestamp(51);
      await mockAggregatorProxy.setLatestRoundData({
        roundId: 4,
        answer: 1,
        startedAt: 1,
        updatedAt: 1,
        answeredInRound: 1,
      });

      await mockAggregatorProxy.setLatestRound(4);

      await mockAggregatorProxy.setTimestamp(0, 10);
      await mockAggregatorProxy.setTimestamp(1, 20);
      await mockAggregatorProxy.setTimestamp(2, 30);
      await mockAggregatorProxy.setTimestamp(3, 40);
      await mockAggregatorProxy.setTimestamp(4, 50);
      await mockAggregatorProxy.setLatestAnswer(420);

      //set the price of the round that'll get picked
      await mockAggregatorProxy.setRoundIdAnswer(2, 420);

      await chainlinkOracleManager
        .connect(oracleManagerAccount)
        .addAssetOracle(assetOne, mockAggregatorProxy.address);
    };

    it("Should search timestamps successfully and return the round after the timestamp passed", async function () {
      await setUpTestWithMockAggregator();

      expect(
        await chainlinkOracleManager.searchRoundToSubmit(assetOne, 32)
      ).to.be.equal(3);

      expect(
        await chainlinkOracleManager.searchRoundToSubmit(assetOne, 40)
      ).to.be.equal(4);
    });

    it("Integration Test: Should submit the correct price to the price registry", async function () {
      //use the real price registry instead of the mock
      await mockConfig.mock.protocolAddresses
        .withArgs(ethers.utils.id("priceRegistry"))
        .returns(priceRegistry.address);

      await setUpTestWithMockAggregator();

      //price should not be set initially
      await expect(
        priceRegistry.getSettlementPrice(
          chainlinkOracleManager.address,
          assetOne,
          32
        )
      ).to.be.revertedWith("PriceRegistry: No settlement price has been set");

      await expect(
        chainlinkOracleManager
          .connect(normalUserAccount)
          .setExpiryPriceInRegistry(assetOne, 32, ethers.utils.randomBytes(32))
      )
        .to.emit(chainlinkOracleManager, "PriceRegistrySubmission")
        .withArgs(assetOne, 32, 420, 2, normalUserAccountAddress, false);

      //price should be set after we set it through the oracle
      expect(
        await priceRegistry.getSettlementPrice(
          chainlinkOracleManager.address,
          assetOne,
          32
        )
      ).to.equal(420);
    });

    it("Integration Test: Should submit the correct price to the price registry when submitting a round directly", async function () {
      //use the real price registry instead of the mock
      await mockConfig.mock.protocolAddresses
        .withArgs(ethers.utils.id("priceRegistry"))
        .returns(priceRegistry.address);

      await setUpTestWithMockAggregator();

      //price should not be set initially
      await expect(
        priceRegistry.getSettlementPrice(
          chainlinkOracleManager.address,
          assetOne,
          32
        )
      ).to.be.revertedWith("PriceRegistry: No settlement price has been set");

      await expect(
        chainlinkOracleManager
          .connect(normalUserAccount)
          .setExpiryPriceInRegistryByRound(assetOne, 32, 3)
      )
        .to.emit(chainlinkOracleManager, "PriceRegistrySubmission")
        .withArgs(assetOne, 32, 420, 2, normalUserAccountAddress, false);

      //price should be set after we set it through the oracle
      expect(
        await priceRegistry.getSettlementPrice(
          chainlinkOracleManager.address,
          assetOne,
          32
        )
      ).to.equal(420);

      await expect(
        chainlinkOracleManager
          .connect(normalUserAccount)
          .setExpiryPriceInRegistryByRound(assetOne, 22, 1)
      ).to.be.revertedWith(
        "ChainlinkOracleManager: The round posted is not after the expiry timestamp"
      );

      await expect(
        chainlinkOracleManager
          .connect(normalUserAccount)
          .setExpiryPriceInRegistryByRound(assetOne, 10, 4)
      ).to.be.revertedWith(
        "ChainlinkOracleManager: Expiry round prior to the one posted is after the expiry timestamp"
      );
    });

    it("Integration Test: Should fail to submit a round for an asset that doesn't exist in the oracle", async function () {
      //use the real price registry instead of the mock
      await mockConfig.mock.protocolAddresses
        .withArgs(ethers.utils.id("priceRegistry"))
        .returns(priceRegistry.address);

      await setUpTestWithMockAggregator();

      await expect(
        chainlinkOracleManager
          .connect(normalUserAccount)
          .setExpiryPriceInRegistryByRound(assetTwo, 22, 1)
      ).to.be.revertedWith(
        "ProviderOracleManager: Oracle doesn't exist for that asset"
      );
    });
  });
});
