import { Contract, Signer, ContractFactory } from "ethers";
import { ethers } from "hardhat"; //to be explicit
import { use, expect } from "chai";
import { beforeEach, describe, it } from "mocha";

import { MockProvider } from "@ethereum-waffle/provider";
import { waffleChai } from "@ethereum-waffle/chai";
import { deployMockContract } from "@ethereum-waffle/mock-contract";

import CONFIG from "../artifacts/contracts/protocol/QuantConfig.sol/QuantConfig.json";

use(waffleChai);

describe("Chainlink Oracle Manager", function () {
  let ChainlinkOracleManager: ContractFactory;
  let deployedChainlinkOracleManager: Contract;
  let mockConfig: Contract;
  let owner: Signer;
  let addr1: Signer;
  let addr2: Signer;

  async function setupMocks() {
    const [sender, receiver] = new MockProvider().getWallets();
    mockConfig = await deployMockContract(sender, CONFIG.abi);
  }

  beforeEach(async function () {
    ChainlinkOracleManager = await ethers.getContractFactory(
      "ChainlinkOracleManager"
    );
    [owner, addr1, addr2] = await ethers.getSigners();

    await setupMocks();

    deployedChainlinkOracleManager = await ChainlinkOracleManager.deploy(
      mockConfig.address
    );
    await deployedChainlinkOracleManager.deployed();
  });

  //todo: these should be externalised so they can be added to any implementation of ProviderOracleManager
  describe("ProviderOracleManager", function () {
    it("Should allow the addition of asset oracles, get number of assets and fetch prices", async function () {
      //check assets is 0
      //add an asset
      //check assets is 1
      //add an asset
      //check assets is 2
      //get price of asset 1 and check its correct
      //get price of asset 2 and check its correct
    });

    it("Should not allow the addition of the same asset twice", async function () {
      //check assets is 0
      //add an asset
      //check assets is 1
      //add the same asset - fail
    });

    it("Should not allow a non oracle manager account to add an asset", async function () {
      //add an asset - fail
    });
  });

  describe("Pricing", function () {
    it("Should allow a mint, and update total debt correctly", async function () {
      //do stuff
    });
  });
});
