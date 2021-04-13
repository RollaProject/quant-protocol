import { BigNumber, Signer } from "ethers";
import { ethers } from "hardhat";
import { beforeEach, describe } from "mocha";
import { AssetsRegistry, OptionsFactory } from "../typechain";
import { CollateralToken } from "../typechain/CollateralToken";
import { MockERC20 } from "../typechain/MockERC20";
import { QuantConfig } from "../typechain/QuantConfig";
import { expect, provider } from "./setup";
import {
  deployAssetsRegistry,
  deployCollateralToken,
  deployOptionsFactory,
  deployQuantConfig,
  mockERC20,
} from "./testUtils";

describe("OptionsFactory", () => {
  let quantConfig: QuantConfig;
  let collateralToken: CollateralToken;
  let timelockController: Signer;
  let secondAccount: Signer;
  let assetsRegistryManager: Signer;
  let WETH: MockERC20;
  let USDC: MockERC20;
  let optionsFactory: OptionsFactory;
  let assetsRegistry: AssetsRegistry;
  let futureTimestamp: number;
  let samplePutOptionParameters: [
    string,
    string,
    string,
    BigNumber,
    BigNumber,
    boolean
  ];
  let sampleCollateralTokenParameters: [
    string,
    string,
    string,
    string,
    BigNumber,
    BigNumber,
    boolean
  ];

  beforeEach(async () => {
    [
      timelockController,
      secondAccount,
      assetsRegistryManager,
    ] = await provider.getWallets();

    quantConfig = await deployQuantConfig(timelockController, [
      {
        addresses: [await assetsRegistryManager.getAddress()],
        role: ethers.utils.id("ASSET_REGISTRY_MANAGER_ROLE"),
      },
    ]);

    WETH = await mockERC20(timelockController, "WETH", "Wrapped Ether");
    USDC = await mockERC20(timelockController, "USDC", "USD Coin", 6);

    collateralToken = await deployCollateralToken(
      timelockController,
      quantConfig
    );

    assetsRegistry = await deployAssetsRegistry(
      timelockController,
      quantConfig
    );

    await quantConfig
      .connect(timelockController)
      .setAssetsRegistry(assetsRegistry.address);

    await assetsRegistry
      .connect(assetsRegistryManager)
      .addAsset(
        WETH.address,
        await WETH.name(),
        await WETH.symbol(),
        await WETH.decimals()
      );

    optionsFactory = await deployOptionsFactory(
      timelockController,
      quantConfig,
      collateralToken
    );

    await quantConfig.grantRole(
      await quantConfig.COLLATERAL_CREATOR_ROLE(),
      optionsFactory.address
    );

    // 30 days from now
    futureTimestamp = Math.floor(Date.now() / 1000) + 30 * 24 * 3600;

    samplePutOptionParameters = [
      WETH.address,
      USDC.address,
      ethers.constants.AddressZero,
      ethers.utils.parseUnits("1400", await USDC.decimals()),
      ethers.BigNumber.from(futureTimestamp),
      false,
    ];

    sampleCollateralTokenParameters = [
      WETH.address,
      USDC.address,
      ethers.constants.AddressZero,
      ethers.constants.AddressZero,
      ethers.utils.parseUnits("1400", await USDC.decimals()),
      ethers.BigNumber.from(futureTimestamp),
      false,
    ];
  });

  describe("createOption", () => {
    it("Anyone should be able to create new options", async () => {
      await expect(optionsFactory.qTokens(ethers.BigNumber.from("0"))).to.be
        .reverted;

      const qTokenAddress = await optionsFactory.getTargetQTokenAddress(
        ...samplePutOptionParameters
      );

      const collateralTokenId = await optionsFactory.getTargetCollateralTokenId(
        ...sampleCollateralTokenParameters
      );

      await expect(
        optionsFactory
          .connect(secondAccount)
          .createOption(...samplePutOptionParameters)
      )
        .to.emit(optionsFactory, "OptionCreated")
        .withArgs(
          qTokenAddress,
          await secondAccount.getAddress(),
          ...samplePutOptionParameters.slice(0, 5),
          collateralTokenId,
          ethers.BigNumber.from("1"),
          false
        );

      expect(await optionsFactory.qTokens(ethers.BigNumber.from("0"))).to.equal(
        qTokenAddress
      );

      expect(
        await collateralToken.collateralTokensIds(ethers.BigNumber.from("0"))
      ).to.equal(collateralTokenId);
    });

    it("Should revert when trying to create an option that would have already expired", async () => {
      const pastTimestamp = "1582602164";
      await expect(
        optionsFactory.createOption(
          WETH.address,
          USDC.address,
          ethers.constants.AddressZero,
          ethers.utils.parseUnits("1400", await USDC.decimals()),
          ethers.BigNumber.from(pastTimestamp),
          false
        )
      ).to.be.revertedWith("OptionsFactory: given expiry time is in the past");
    });

    it("Should revert when trying to create a duplicate option", async () => {
      await optionsFactory
        .connect(secondAccount)
        .createOption(...samplePutOptionParameters);

      await expect(
        optionsFactory
          .connect(secondAccount)
          .createOption(...samplePutOptionParameters)
      ).to.be.revertedWith("OptionsFactory: option already created");
    });

    it("Should revert when trying to create a PUT option with a strike price of 0", async () => {
      await expect(
        optionsFactory
          .connect(secondAccount)
          .createOption(
            WETH.address,
            USDC.address,
            ethers.constants.AddressZero,
            ethers.BigNumber.from("0"),
            futureTimestamp,
            false
          )
      ).to.be.revertedWith("OptionsFactory: strike for put can't be 0");
    });

    it("Should revert when trying to create an option with an underlying that's not in the assets registry", async () => {
      await expect(
        optionsFactory
          .connect(secondAccount)
          .createOption(
            ethers.constants.AddressZero,
            USDC.address,
            ethers.constants.AddressZero,
            ethers.utils.parseUnits("1400", await USDC.decimals()),
            futureTimestamp,
            false
          )
      ).to.be.revertedWith(
        "OptionsFactory: underlying is not in the assets registry"
      );
    });
  });

  describe("getCollateralToken", () => {
    it("Should return the ID of the correct CollateralToken", async () => {
      const collateralTokenId = await optionsFactory.getTargetCollateralTokenId(
        ...sampleCollateralTokenParameters
      );

      await optionsFactory
        .connect(secondAccount)
        .createOption(...samplePutOptionParameters);

      expect(
        await optionsFactory.getCollateralToken(
          ...sampleCollateralTokenParameters
        )
      ).to.equal(collateralTokenId);
    });
  });

  describe("getQToken", () => {
    it("Should return the address of the correct QToken", async () => {
      const qTokenAddress = await optionsFactory.getTargetQTokenAddress(
        ...samplePutOptionParameters
      );

      await optionsFactory
        .connect(secondAccount)
        .createOption(...samplePutOptionParameters);

      expect(
        await optionsFactory.getQToken(...samplePutOptionParameters)
      ).to.equal(qTokenAddress);
    });
  });

  describe("getOptionsLength", () => {
    it("Should return the correct number of options created by the factory", async () => {
      expect(await optionsFactory.getOptionsLength()).to.equal(
        ethers.BigNumber.from("0")
      );

      await optionsFactory
        .connect(secondAccount)
        .createOption(...samplePutOptionParameters);

      expect(await optionsFactory.getOptionsLength()).to.equal(
        ethers.BigNumber.from("1")
      );
    });
  });
});
