const {ethers} = require("hardhat"); //to be explicit
const {use, expect} = require("chai");
const {utils} = require("ethers");

const {MockProvider} = require("@ethereum-waffle/provider");
const {waffleChai} = require("@ethereum-waffle/chai");
const {deployMockContract} = require("@ethereum-waffle/mock-contract");

const CONFIG = require("../../../artifacts/@openzeppelin/contracts/access/AccessControl.sol/AccessControl.json").abi;
//const CONFIG = require("../../../artifacts/contracts/protocol/QuantConfig.sol/QuantConfig.json").abi;

use(waffleChai);

describe("Chainlink Oracle Manager", function () {
    let ChainlinkOracleManager;
    let deployedChainlinkOracleManager;
    let mockConfig;
    let owner;
    let addr1;
    let addr2;
    let addrs;

    async function setupMocks() {
        const [sender, receiver] = new MockProvider().getWallets();
        mockConfig = await deployMockContract(sender, CONFIG.abi);
    }

    beforeEach(async function () {
        ChainlinkOracleManager = await ethers.getContractFactory("ChainlinkOracleManager");
        [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

        await setupMocks();

        deployedChainlinkOracleManager = await ChainlinkOracleManager.deploy(mockConfig.address);
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
    })

    describe("Pricing", function () {
        it("Should allow a mint, and update total debt correctly", async function () {

        });
    });
});
