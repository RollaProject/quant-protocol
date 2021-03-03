import { BigNumber, Signer } from "ethers";
import { ethers } from "hardhat";
import { beforeEach, describe } from "mocha";
import { OptionsFactory } from "../typechain";
import { CollateralToken } from "../typechain/CollateralToken";
import { MockERC20 } from "../typechain/MockERC20";
import { QuantConfig } from "../typechain/QuantConfig";
import { expect, provider } from "./setup";
import {
  deployCollateralToken,
  deployOptionsFactory,
  deployQuantConfig,
  mockERC20,
} from "./testUtils";

describe("OptionsFactory", () => {
  let quantConfig: QuantConfig;
  let collateralToken: CollateralToken;
  let admin: Signer;
  let secondAccount: Signer;
  let WETH: MockERC20;
  let USDC: MockERC20;
  let optionsFactory: OptionsFactory;
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
    BigNumber,
    BigNumber,
    BigNumber,
    boolean
  ];

  beforeEach(async () => {
    [admin, secondAccount] = await provider.getWallets();

    quantConfig = await deployQuantConfig(admin);

    WETH = await mockERC20(admin, "WETH");
    USDC = await mockERC20(admin, "USDC");

    collateralToken = await deployCollateralToken(admin, quantConfig);

    optionsFactory = await deployOptionsFactory(
      admin,
      quantConfig,
      collateralToken
    );

    await quantConfig.grantRole(
      await quantConfig.OPTIONS_CONTROLLER_ROLE(),
      optionsFactory.address
    );

    // 30 days from now
    futureTimestamp = Math.floor(Date.now() / 1000) + 30 * 24 * 3600;

    samplePutOptionParameters = [
      WETH.address,
      USDC.address,
      ethers.constants.AddressZero,
      ethers.BigNumber.from("1400"),
      ethers.BigNumber.from(futureTimestamp),
      false,
    ];

    sampleCollateralTokenParameters = [
      WETH.address,
      USDC.address,
      ethers.constants.AddressZero,
      ethers.BigNumber.from("1400"),
      ethers.BigNumber.from(futureTimestamp),
      ethers.BigNumber.from("0"),
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
          ethers.BigNumber.from("1400"),
          ethers.BigNumber.from(pastTimestamp),
          false
        )
      ).to.be.revertedWith("OptionsFactory: given expiry time is in the past");
    });

    it("Should revert when trying to create a duplicate option", async () => {
      await optionsFactory
        .connect(admin)
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
  });

  describe("getCollateralToken", () => {
    it("Should return the ID of the correct CollateralToken", async () => {
      const collateralTokenId = await optionsFactory.getTargetCollateralTokenId(
        ...sampleCollateralTokenParameters
      );

      await optionsFactory
        .connect(admin)
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
        .connect(admin)
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
        .connect(admin)
        .createOption(...samplePutOptionParameters);

      expect(await optionsFactory.getOptionsLength()).to.equal(
        ethers.BigNumber.from("1")
      );
    });
  });
});
