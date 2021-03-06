import { waffleChai } from "@ethereum-waffle/chai";
import { deployMockContract } from "@ethereum-waffle/mock-contract";
import { MockProvider } from "@ethereum-waffle/provider";
import { use } from "chai";
import { Contract, ContractFactory, Signer } from "ethers";
import { ethers } from "hardhat"; //to be explicit
import { beforeEach, describe, it } from "mocha";
import CONFIG from "../artifacts/contracts/protocol/QuantConfig.sol/QuantConfig.json";
import AGGREGATOR from "../artifacts/contracts/external/chainlink/IEACAggregatorProxy.sol/IEACAggregatorProxy.json";
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
  let owner: Signer;
  let admin: Signer;
  let addr1: Signer;
  const assetOne = "0x000000000000000000000000000000000000000A";
  const assetTwo = "0x000000000000000000000000000000000000000B";
  const oracleOne = "0x00000000000000000000000000000000000000A0";
  const oracleTwo = "0x00000000000000000000000000000000000000B0";
  const oracleThree = "0x00000000000000000000000000000000000000C0";
  const fallbackPeriodSeconds = 100;

  async function setupMocks() {
    const [sender, receiver] = new MockProvider().getWallets();
    mockConfig = await deployMockContract(sender, CONFIG.abi);
    mockAggregator = await deployMockContract(sender, AGGREGATOR.abi);
    mockAggregatorTwo = await deployMockContract(sender, AGGREGATOR.abi);
  }

  beforeEach(async function () {
    ChainlinkOracleManager = await ethers.getContractFactory(
      "ChainlinkOracleManager"
    );
    [owner, admin, addr1] = await ethers.getSigners();

    await setupMocks();

    chainlinkOracleManager = <ChainlinkOracleManager>(
      await ChainlinkOracleManager.deploy(
        mockConfig.address,
        fallbackPeriodSeconds
      )
    );
    await chainlinkOracleManager.deployed();
  });

  //todo: these should be externalised so they can be added to any implementation of ProviderOracleManager
  describe("ProviderOracleManager", function () {
    it("Should allow the addition of asset oracles, get number of assets and fetch prices", async function () {
      await mockConfig.mock.hasRole.returns(true);
      await mockConfig.mock.ORACLE_MANAGER_ROLE.returns(
        "0x47173285a8d7341e5e972fc677286384f802f8ef42a5ec5f03bbfa254cb01fad"
      );

      expect(await chainlinkOracleManager.getAssetsLength()).to.be.equal(0);
      await chainlinkOracleManager.addAssetOracle(assetOne, oracleOne);

      expect(await chainlinkOracleManager.getAssetsLength()).to.be.equal(1);
      await chainlinkOracleManager.addAssetOracle(assetTwo, oracleTwo);

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
        await chainlinkOracleManager.addAssetOracle(assetTwo, oracleTwo)
      ).to.be.revertedWith("OracleManager: Oracle already set for asset");
      expect(
        await chainlinkOracleManager.addAssetOracle(assetTwo, oracleThree)
      ).to.be.revertedWith("OracleManager: Oracle already set for asset");

      //todo add event check in here...
    });

    it("Should not allow a non oracle manager account to add an asset", async function () {
      expect(await chainlinkOracleManager.getAssetsLength()).to.be.equal(0);
      expect(
        await chainlinkOracleManager.addAssetOracle(assetOne, oracleOne)
      ).to.be.revertedWith(
        "OracleManager: Only an oracle admin can add an oracle"
      );
    });
  });

  describe("Pricing", function () {
    it("Fallback method should allow a fallback submitter to submit only after the fallback period", async function () {
      //todo: add the fallback price role to the admin

      await chainlinkOracleManager.addAssetOracle(assetOne, oracleOne);
      expect(
        await chainlinkOracleManager.setExpiryPriceInRegistryFallback(
          assetOne,
          10,
          5000
        )
      ).to.be.revertedWith(
        "ChainlinkOracleManager: Only the fallback price submitter can submit a fallback price"
      );

      //todo: set fallback to 500
      expect(
        await chainlinkOracleManager
          .connect(owner)
          .setExpiryPriceInRegistryFallback(
            assetOne,
            Math.round(Date.now() / 1000),
            5000
          )
      ).to.be.revertedWith(
        "ChainlinkOracleManager: The fallback price period has not passed since the timestamp"
      );

      //todo: set fallback to 0
      //todo: add args for event
      expect(
        await chainlinkOracleManager
          .connect(owner)
          .setExpiryPriceInRegistryFallback(
            assetOne,
            Math.round(Date.now() / 1000),
            5000
          )
      )
        .to.emit(chainlinkOracleManager, "PriceRegistrySubmission")
        .withArgs();

      //todo mock priceregistry and expect price registry to have been called with right param...
    });

    it("Should fetch the current price of the asset provided correctly", async function () {
      await mockAggregator.mock.latestAnswer.returns(0);
      await mockAggregatorTwo.mock.latestAnswer.returns(2);

      await mockConfig.mock.hasRole.returns(true);
      await mockConfig.mock.ORACLE_MANAGER_ROLE.returns(
        "0x47173285a8d7341e5e972fc677286384f802f8ef42a5ec5f03bbfa254cb01fad"
      );

      expect(
        await chainlinkOracleManager.getCurrentPrice(mockAggregator.address)
      ).to.be.revertedWith("ChainlinkOracleManager: Asset not supported");

      await chainlinkOracleManager
        .connect(admin)
        .addAssetOracle(assetOne, mockAggregator.address);

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
      await mockConfig.mock.hasRole.returns(true);
      await mockConfig.mock.ORACLE_MANAGER_ROLE.returns(
        "0x47173285a8d7341e5e972fc677286384f802f8ef42a5ec5f03bbfa254cb01fad"
      );

      await chainlinkOracleManager
        .connect(admin)
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
