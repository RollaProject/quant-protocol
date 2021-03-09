import { ethers } from "hardhat";
import { deployMockContract } from "@ethereum-waffle/mock-contract";
import { ContractFactory, Signer } from "ethers";
import { MockContract } from "ethereum-waffle";
import CONFIG from "../artifacts/contracts/protocol/QuantConfig.sol/QuantConfig.json";
import AGGREGATOR from "../artifacts/contracts/external/chainlink/IEACAggregatorProxy.sol/IEACAggregatorProxy.json";
import PRICE_REGISTRY from "../artifacts/contracts/protocol/pricing/PriceRegistry.sol/PriceRegistry.json";
import CHAINLINK_ORACLE_MANAGER from "../artifacts/contracts/protocol/pricing/oracle/ChainlinkOracleManager.sol/ChainlinkOracleManager.json";
import { provider, expect } from "./setup";
import { beforeEach, describe, it } from "mocha";
import { ChainlinkOracleManager } from "../typechain";
import { Address } from "hardhat-deploy/dist/types";

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

  const assetOne = ethers.utils.getAddress(
    "0x000000000000000000000000000000000000000A"
  );
  const assetTwo = ethers.utils.getAddress(
    "0x000000000000000000000000000000000000000B"
  );
  const oracleOne = ethers.utils.getAddress(
    "0x00000000000000000000000000000000000000A0"
  );
  const oracleTwo = ethers.utils.getAddress(
    "0x00000000000000000000000000000000000000B0"
  );
  const oracleThree = ethers.utils.getAddress(
    "0x00000000000000000000000000000000000000C0"
  );
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

    console.log({ oracleManagerRole, fallbackPriceRole });

    mockConfig = await deployMockContract(owner, CONFIG.abi);
    mockAggregator = await deployMockContract(owner, AGGREGATOR.abi);
    mockAggregatorTwo = await deployMockContract(owner, AGGREGATOR.abi);
    mockPriceRegistry = await deployMockContract(owner, PRICE_REGISTRY.abi);

    await mockConfig.mock.ORACLE_MANAGER_ROLE.returns(oracleManagerRole);
    await mockConfig.mock.FALLBACK_PRICE_ROLE.returns(fallbackPriceRole);
    await mockConfig.mock.priceRegistry.returns(mockPriceRegistry.address);

    oracleManagerAccountAddress = (
      await oracleManagerAccount.getAddress()
    ).toLowerCase();
    normalUserAccountAddress = await normalUserAccount.getAddress();
    fallbackPriceAccountAddress = await fallbackPriceAccount.getAddress();

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

    //await mockConfig.mock.hasRole.returns(true);

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

  //todo: these should be externalised so they can be added to any implementation of ProviderOracleManager
  describe("ProviderOracleManager", function () {
    it("Should allow the addition of asset oracles, get number of assets and fetch prices", async function () {
      expect(await chainlinkOracleManager.getAssetsLength()).to.be.equal(0);

      console.log(oracleManagerRole);
      console.log(oracleManagerAccountAddress);

      await expect(
        chainlinkOracleManager
          .connect(oracleManagerAccount)
          .addAssetOracle(assetOne, oracleOne)
      )
        .to.emit(chainlinkOracleManager, "OracleAdded")
        .withArgs(assetOne, oracleOne);

      expect(await chainlinkOracleManager.getAssetsLength()).to.be.equal(1);
    });
    /*
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
    */
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
