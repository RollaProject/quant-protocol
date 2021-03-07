import { waffleChai } from "@ethereum-waffle/chai";
import { deployMockContract } from "@ethereum-waffle/mock-contract";
import { MockProvider } from "@ethereum-waffle/provider";
import { use } from "chai";
import { ContractFactory, Signer } from "ethers";
import { ethers, waffle } from "hardhat"; //to be explicit
import { beforeEach, describe, it } from "mocha";
import CHAINLINK_ORACLE_MANAGER from "../artifacts/contracts/protocol/pricing/oracle/ChainlinkOracleManager.sol/ChainlinkOracleManager.json";
import CONFIG from "../artifacts/contracts/protocol/QuantConfig.sol/QuantConfig.json";
import AGGREGATOR from "../artifacts/contracts/external/chainlink/IEACAggregatorProxy.sol/IEACAggregatorProxy.json";
import PRICE_REGISTRY from "../artifacts/contracts/protocol/pricing/PriceRegistry.sol/PriceRegistry.json";
import { MockContract } from "ethereum-waffle";
import { expect } from "./setup";
import { ChainlinkOracleManager } from "../typechain";

use(waffleChai);

describe("Chainlink Oracle Manager", function () {
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
  const assetOne = "0x000000000000000000000000000000000000000A";
  const assetTwo = "0x000000000000000000000000000000000000000B";
  const oracleOne = "0x00000000000000000000000000000000000000A0";
  const oracleTwo = "0x00000000000000000000000000000000000000B0";
  const oracleThree = "0x00000000000000000000000000000000000000C0";
  const oracleManagerRole =
    "0x47173285a8d7341e5e972fc677286384f802f8ef42a5ec5f03bbfa254cb01fad";
  const fallbackPriceRole =
    "0x47173285a8d7341e5e972fc677286384f802f8ef42a5ec5f03bbfa254cb01fae";

  async function setupMocks() {
    const [sender, receiver] = new MockProvider().getWallets();
    mockConfig = await deployMockContract(sender, CONFIG.abi);
    mockAggregator = await deployMockContract(sender, AGGREGATOR.abi);
    mockAggregatorTwo = await deployMockContract(sender, AGGREGATOR.abi);
    mockPriceRegistry = await deployMockContract(sender, PRICE_REGISTRY.abi);

    const contractFactory = new ContractFactory(
      CHAINLINK_ORACLE_MANAGER.abi,
      CHAINLINK_ORACLE_MANAGER.bytecode,
      sender
    );

    chainlinkOracleManager = <ChainlinkOracleManager>(
      await contractFactory.deploy(mockConfig.address, 0)
    );

    await mockConfig.mock.ORACLE_MANAGER_ROLE.returns(oracleManagerRole);
    await mockConfig.mock.FALLBACK_PRICE_ROLE.returns(fallbackPriceRole);
    await mockConfig.mock.priceRegistry.returns(mockPriceRegistry.address);

    const oracleManagerAccountAddress = await oracleManagerAccount.getAddress();
    const normalUserAccountAddress = await normalUserAccount.getAddress();
    const fallbackPriceAccountAddress = await fallbackPriceAccount.getAddress();

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
  }

  beforeEach(async function () {
    [
      owner,
      oracleManagerAccount,
      normalUserAccount,
      fallbackPriceAccount,
    ] = await ethers.getSigners();

    await setupMocks();
  });

  //todo: these should be externalised so they can be added to any implementation of ProviderOracleManager
  describe("ProviderOracleManager", function () {
    it("Should allow the addition of asset oracles, get number of assets and fetch prices", async function () {
      expect(await chainlinkOracleManager.getAssetsLength()).to.be.equal(0);
      expect(
        await chainlinkOracleManager
          .connect(oracleManagerAccount)
          .addAssetOracle(assetOne, oracleOne)
      )
        .to.emit(chainlinkOracleManager, "OracleAdded")
        .withArgs(assetOne, oracleOne);

      expect(await chainlinkOracleManager.getAssetsLength()).to.be.equal(1);
      expect(
        await chainlinkOracleManager
          .connect(oracleManagerAccount)
          .addAssetOracle(assetTwo, oracleTwo)
      )
        .to.emit(chainlinkOracleManager, "OracleAdded")
        .withArgs(assetOne, oracleOne);

      expect(await chainlinkOracleManager.getAssetsLength()).to.be.equal(2);
      expect(await chainlinkOracleManager.assets(0)).to.be.equal(assetOne);
      expect(await chainlinkOracleManager.assets(1)).to.be.equal(assetTwo);
      expect(await chainlinkOracleManager.assetOracles(assetOne)).to.be.equal(
        oracleOne
      );
      expect(await chainlinkOracleManager.assetOracles(assetTwo)).to.be.equal(
        oracleTwo
      );
      expect(
        await chainlinkOracleManager
          .connect(oracleManagerAccount)
          .addAssetOracle(assetTwo, oracleTwo)
      ).to.be.revertedWith("OracleManager: Oracle already set for asset");
      expect(
        await chainlinkOracleManager
          .connect(oracleManagerAccount)
          .addAssetOracle(assetTwo, oracleThree)
      ).to.be.revertedWith("OracleManager: Oracle already set for asset");
    });

    it("Should not allow a non oracle manager account to add an asset", async function () {
      expect(await chainlinkOracleManager.getAssetsLength()).to.be.equal(0);
      expect(
        await chainlinkOracleManager
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

      //todo: add args for event
      expect(
        await chainlinkOracleManager
          .connect(fallbackPriceAccount)
          .setExpiryPriceInRegistryFallback(assetOne, expiryTimestamp, 5000)
      ).to.emit(chainlinkOracleManager, "PriceRegistrySubmission");
      //.withArgs();

      expect("setSettlementPrice").to.be.calledOnContractWith(
        mockPriceRegistry,
        [assetOne, expiryTimestamp, 5000]
      );
    });

    it("Fallback method should not allow a fallback submitter to submit before the fallback period", async function () {
      chainlinkOracleManager = <ChainlinkOracleManager>(
        await ChainlinkOracleManager.deploy(mockConfig.address, 500)
      );
      await chainlinkOracleManager.deployed();

      await chainlinkOracleManager.addAssetOracle(assetOne, oracleOne);
      expect(
        await chainlinkOracleManager
          .connect(normalUserAccount)
          .setExpiryPriceInRegistryFallback(assetOne, 10, 5000)
      ).to.be.revertedWith(
        "ChainlinkOracleManager: Only the fallback price submitter can submit a fallback price"
      );

      expect(
        await chainlinkOracleManager
          .connect(fallbackPriceAccount)
          .setExpiryPriceInRegistryFallback(
            assetOne,
            Math.round(Date.now() / 1000),
            5000
          )
      ).to.be.revertedWith(
        "ChainlinkOracleManager: The fallback price period has not passed since the timestamp"
      );
    });

    it("Should fetch the current price of the asset provided correctly", async function () {
      await mockAggregator.mock.latestAnswer.returns(0);
      await mockAggregatorTwo.mock.latestAnswer.returns(2);

      expect(
        await chainlinkOracleManager.getCurrentPrice(mockAggregator.address)
      ).to.be.revertedWith("ChainlinkOracleManager: Asset not supported");

      await chainlinkOracleManager
        .connect(oracleManagerAccount)
        .addAssetOracle(assetOne, mockAggregator.address);

      await chainlinkOracleManager
        .connect(oracleManagerAccount)
        .addAssetOracle(assetTwo, mockAggregatorTwo.address);

      expect(
        await chainlinkOracleManager.getCurrentPrice(mockAggregator.address)
      ).to.be.revertedWith("ChainlinkOracleManager: No pricing data available");

      expect(
        await chainlinkOracleManager.getCurrentPrice(mockAggregatorTwo.address)
      ).to.be.equal(2);

      await mockAggregator.mock.latestAnswer.returns(1);

      expect(
        await chainlinkOracleManager.getCurrentPrice(mockAggregator.address)
      ).to.be.equal(1);

      expect(
        await chainlinkOracleManager.getCurrentPrice(mockAggregatorTwo.address)
      ).to.be.equal(2);
    });

    it("Should find the correct round to submit", async function () {
      await chainlinkOracleManager
        .connect(oracleManagerAccount)
        .addAssetOracle(assetOne, mockAggregator.address);

      expect(
        await mockAggregator.mock.latestTimestamp.returns(
          Math.round(Date.now() / 1000) - 100
        )
      ).to.be.revertedWith(
        "ChainlinkOracleManager: The latest round timestamp is not after the expiry timestamp"
      );

      expect(
        await mockAggregator.mock.latestTimestamp.returns(
          Math.round(Date.now() / 1000) + 100
        )
      ).to.be.equal(0);
    });

    //todo does search work if theres only 1 round?
  });
});
