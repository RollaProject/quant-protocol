import { deployContract } from "ethereum-waffle";
import { Signer } from "ethers";
import { waffle } from "hardhat";
import { beforeEach, describe, it } from "mocha";
import BasicTokenJSON from "../artifacts/contracts/protocol/test/BasicERC20.sol/BasicERC20.json";
import { AssetsRegistry, MockERC20, QuantConfig } from "../typechain";
import { expect, provider } from "./setup";
import {
  deployAssetsRegistry,
  deployQuantConfig,
  mockERC20,
} from "./testUtils";

const { deployMockContract } = waffle;

type AssetProperties = [string, string, string, number];

describe("AssetsRegistry", () => {
  let quantConfig: QuantConfig;
  let assetsRegistry: AssetsRegistry;
  let admin: Signer;
  let secondAccount: Signer;
  let WETH: MockERC20;
  let USDC: MockERC20;
  let WETHProperties: AssetProperties;
  let USDCProperties: AssetProperties;

  beforeEach(async () => {
    [admin, secondAccount] = await provider.getWallets();

    WETH = await mockERC20(admin, "WETH", "Wrapped Ether");
    USDC = await mockERC20(admin, "USDC", "USD Coin", 6);

    WETHProperties = [
      WETH.address,
      await WETH.name(),
      await WETH.symbol(),
      await WETH.decimals(),
    ];

    USDCProperties = [
      USDC.address,
      await USDC.name(),
      await USDC.symbol(),
      await USDC.decimals(),
    ];

    quantConfig = await deployQuantConfig(admin);

    assetsRegistry = await deployAssetsRegistry(admin, quantConfig);
  });

  describe("addAsset", () => {
    it("Admin should be able to add assets to the registry", async () => {
      await assetsRegistry.connect(admin).addAsset(...WETHProperties);

      expect(await assetsRegistry.assetProperties(WETH.address)).to.eql(
        WETHProperties.slice(1)
      );
    });

    it("Should revert when an unauthorized account tries to add an asset", async () => {
      await expect(
        assetsRegistry.connect(secondAccount).addAsset(...USDCProperties)
      ).to.be.revertedWith("AssetsRegistry: only admins can add assets");
    });

    it("Should revert when trying to add a duplicate asset", async () => {
      await assetsRegistry.connect(admin).addAsset(...WETHProperties);

      await expect(
        assetsRegistry.connect(admin).addAsset(...WETHProperties)
      ).to.be.revertedWith("AssetsRegistry: asset already added");
    });

    it("Should use passed parameters when tokens don't implement optional ERC20 methods", async () => {
      const basicToken = await deployContract(admin, BasicTokenJSON);
      await assetsRegistry
        .connect(admin)
        .addAsset(basicToken.address, "Basic Token", "BASIC", 14);

      expect(await assetsRegistry.assetProperties(basicToken.address)).to.eql([
        "Basic Token",
        "BASIC",
        14,
      ]);
    });

    it("Should emit the AssetAdded event", async () => {
      await expect(assetsRegistry.connect(admin).addAsset(...USDCProperties))
        .to.emit(assetsRegistry, "AssetAdded")
        .withArgs(...USDCProperties);
    });
  });
});
