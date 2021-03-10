import { waffleChai } from "@ethereum-waffle/chai";
import { deployMockContract } from "@ethereum-waffle/mock-contract";
import { MockProvider } from "@ethereum-waffle/provider";
import { use, expect } from "chai";
import { ContractFactory, Signer } from "ethers";
import { ethers, waffle } from "hardhat"; //to be explicit
import { beforeEach, describe, it } from "mocha";
import CHAINLINK_ORACLE_MANAGER from "../artifacts/contracts/protocol/pricing/oracle/ChainlinkOracleManager.sol/ChainlinkOracleManager.json";
import CONFIG from "../artifacts/contracts/protocol/QuantConfig.sol/QuantConfig.json";
import AGGREGATOR from "../artifacts/contracts/external/chainlink/IEACAggregatorProxy.sol/IEACAggregatorProxy.json";
import PRICE_REGISTRY from "../artifacts/contracts/protocol/pricing/PriceRegistry.sol/PriceRegistry.json";
import { MockContract } from "ethereum-waffle";
//import { expect } from "./setup";
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

  describe("Pricing", function () {
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
