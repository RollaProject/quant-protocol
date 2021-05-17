import { deployContract } from "ethereum-waffle";
import { BigNumber, Signer } from "ethers";
import { ethers, waffle } from "hardhat";
import { beforeEach, describe, it } from "mocha";
import BasicTokenJSON from "../artifacts/contracts/test/BasicERC20.sol/BasicERC20.json";
import { AssetsRegistry, MockERC20, QuantConfig } from "../typechain";
import { expect, provider } from "./setup";
import {
  deployAssetsRegistry,
  deployQuantConfig,
  mockERC20,
} from "./testUtils";

const { deployMockContract } = waffle;

type AssetProperties = [string, string, string, number, BigNumber];

describe("AssetsRegistry", () => {
  let quantConfig: QuantConfig;
  let assetsRegistry: AssetsRegistry;
  let deployer: Signer;
  let secondAccount: Signer;
  let WETH: MockERC20;
  let USDC: MockERC20;
  let WETHProperties: AssetProperties;
  let USDCProperties: AssetProperties;

  const quantityTickSize = ethers.BigNumber.from("1000");

  beforeEach(async () => {
    [deployer, secondAccount] = await provider.getWallets();

    WETH = await mockERC20(deployer, "WETH", "Wrapped Ether");
    USDC = await mockERC20(deployer, "USDC", "USD Coin", 6);

    WETHProperties = [
      WETH.address,
      await WETH.name(),
      await WETH.symbol(),
      await WETH.decimals(),
      quantityTickSize,
    ];

    USDCProperties = [
      USDC.address,
      await USDC.name(),
      await USDC.symbol(),
      await USDC.decimals(),
      quantityTickSize,
    ];

    quantConfig = await deployQuantConfig(deployer, [
      {
        addresses: [await deployer.getAddress()],
        role: "ASSETS_REGISTRY_MANAGER_ROLE",
      },
    ]);

    assetsRegistry = await deployAssetsRegistry(deployer, quantConfig);
  });

  describe("addAsset", () => {
    it("AssetsRegistry managers should be able to add assets to the registry", async () => {
      await assetsRegistry.connect(deployer).addAsset(...WETHProperties);

      expect(await assetsRegistry.assetProperties(WETH.address)).to.eql(
        WETHProperties.slice(1)
      );
    });

    it("Should revert when an unauthorized account tries to add an asset", async () => {
      await expect(
        assetsRegistry.connect(secondAccount).addAsset(...USDCProperties)
      ).to.be.revertedWith(
        "AssetsRegistry: only asset registry managers can add assets"
      );
    });

    it("Should revert when trying to add a duplicate asset", async () => {
      await assetsRegistry.connect(deployer).addAsset(...WETHProperties);

      await expect(
        assetsRegistry.connect(deployer).addAsset(...WETHProperties)
      ).to.be.revertedWith("AssetsRegistry: asset already added");
    });

    it("Should use passed parameters when tokens don't implement optional ERC20 methods", async () => {
      const basicToken = await deployContract(deployer, BasicTokenJSON);
      await assetsRegistry
        .connect(deployer)
        .addAsset(
          basicToken.address,
          "Basic Token",
          "BASIC",
          14,
          quantityTickSize
        );

      expect(await assetsRegistry.assetProperties(basicToken.address)).to.eql([
        "Basic Token",
        "BASIC",
        14,
        quantityTickSize,
      ]);
    });

    it("Should emit the AssetAdded event", async () => {
      await expect(assetsRegistry.connect(deployer).addAsset(...USDCProperties))
        .to.emit(assetsRegistry, "AssetAdded")
        .withArgs(...USDCProperties);
    });
  });
});
