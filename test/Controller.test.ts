import { BigNumber, Signer } from "ethers";
import { ethers, waffle } from "hardhat";
import { beforeEach, describe } from "mocha";
import ControllerJSON from "../artifacts/contracts/protocol/Controller.sol/Controller.json";
import { OptionsFactory } from "../typechain";
import { CollateralToken } from "../typechain/CollateralToken";
import { Controller } from "../typechain/Controller";
import { MockERC20 } from "../typechain/MockERC20";
import { QToken } from "../typechain/QToken";
import { QuantConfig } from "../typechain/QuantConfig";
import { expect, provider } from "./setup";
import {
  deployCollateralToken,
  deployOptionsFactory,
  deployQuantConfig,
  mockERC20,
} from "./testUtils";

const { deployContract } = waffle;

type optionParameters = [string, string, string, BigNumber, BigNumber, boolean];

describe("Controller", () => {
  let controller: Controller;
  let quantConfig: QuantConfig;
  let collateralToken: CollateralToken;
  let admin: Signer;
  let secondAccount: Signer;
  let WETH: MockERC20;
  let USDC: MockERC20;
  let optionsFactory: OptionsFactory;
  let futureTimestamp: number;
  let samplePutOptionParameters: optionParameters;
  let sampleCallOptionParameters: optionParameters;
  let qTokenPutAddress: string;
  let qTokenCallAddress: string;

  const aMonth = 30 * 24 * 3600; // in seconds

  beforeEach(async () => {
    [admin, secondAccount] = await provider.getWallets();

    quantConfig = await deployQuantConfig(admin);

    WETH = await mockERC20(admin, "WETH", "Wrapped Ether");
    USDC = await mockERC20(admin, "USDC", "USD Coin", 6);
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
    futureTimestamp = Math.floor(Date.now() / 1000) + aMonth;

    samplePutOptionParameters = [
      WETH.address,
      USDC.address,
      ethers.constants.AddressZero,
      ethers.utils.parseUnits("1400", await USDC.decimals()),
      ethers.BigNumber.from(futureTimestamp),
      false,
    ];
    qTokenPutAddress = await optionsFactory.getTargetQTokenAddress(
      ...samplePutOptionParameters
    );
    await optionsFactory
      .connect(secondAccount)
      .createOption(...samplePutOptionParameters);

    sampleCallOptionParameters = [
      WETH.address,
      USDC.address,
      ethers.constants.AddressZero,
      ethers.utils.parseUnits("2000", await USDC.decimals()),
      ethers.BigNumber.from(futureTimestamp),
      true,
    ];
    qTokenCallAddress = await optionsFactory.getTargetQTokenAddress(
      ...sampleCallOptionParameters
    );
    await optionsFactory
      .connect(secondAccount)
      .createOption(...sampleCallOptionParameters);

    controller = <Controller>(
      await deployContract(admin, ControllerJSON, [
        optionsFactory.address,
        collateralToken.address,
      ])
    );

    await quantConfig.grantRole(
      await quantConfig.OPTIONS_CONTROLLER_ROLE(),
      controller.address
    );
  });

  describe("mintOptionsPosition", () => {
    it("Should revert when trying to mint a non-existent option", async () => {
      await expect(
        controller
          .connect(admin)
          .mintOptionsPosition(
            ethers.constants.AddressZero,
            ethers.BigNumber.from("10")
          )
      ).to.be.revertedWith(
        "Controller: Option needs to be created by the factory first"
      );
    });

    it("Should revert when trying to mint an already expired option", async () => {
      // Take a snapshot of the Hardhat Network
      await provider.send("evm_snapshot", []);

      // Increase time to one hour past the expiry
      await provider.send("evm_mine", [futureTimestamp + 3600]);

      await expect(
        controller
          .connect(admin)
          .mintOptionsPosition(qTokenPutAddress, ethers.BigNumber.from("10"))
      ).to.be.revertedWith("Controller: Cannot mint expired options");

      // Reset the Hardhat Network
      await provider.send("evm_revert", ["0x1"]);
    });

    it("Should transfer the required collateral from the user to mint a CALL option", async () => {
      // user should have 0 WETH initially
      expect(await WETH.balanceOf(await secondAccount.getAddress())).to.equal(
        ethers.BigNumber.from("0")
      );

      // mint WETH to the user account
      await WETH.connect(admin).mint(
        await secondAccount.getAddress(),
        ethers.utils.parseEther("3")
      );
      expect(await WETH.balanceOf(await secondAccount.getAddress())).to.equal(
        ethers.utils.parseEther("3")
      );

      // user needs to approve the controller to use his funds
      await WETH.connect(secondAccount).approve(
        controller.address,
        ethers.utils.parseEther("2")
      );

      // the user mints options through the controller
      await controller
        .connect(secondAccount)
        .mintOptionsPosition(qTokenCallAddress, ethers.BigNumber.from("2"));

      // the user's WETH balance should have decreased
      expect(await WETH.balanceOf(await secondAccount.getAddress())).to.equal(
        ethers.utils.parseEther("1")
      );

      // the controller should have received the user's collateral
      expect(await WETH.balanceOf(controller.address)).to.equal(
        ethers.utils.parseEther("2")
      );
    });

    it("Should transfer the required collateral from the user to mint a PUT option", async () => {
      // user should have 0 USDC initially
      expect(await USDC.balanceOf(await secondAccount.getAddress())).to.equal(
        ethers.BigNumber.from("0")
      );

      // mint USDC to the user account
      await USDC.connect(admin).mint(
        await secondAccount.getAddress(),
        ethers.utils.parseUnits("4000", "6") // USDC has 6 decimals
      );
      expect(await USDC.balanceOf(await secondAccount.getAddress())).to.equal(
        ethers.utils.parseUnits("4000", "6")
      );

      // user needs to approve the controller to use his funds
      await USDC.connect(secondAccount).approve(
        controller.address,
        ethers.utils.parseUnits("2800", "6")
      );

      // the user mints options through the controller
      await controller
        .connect(secondAccount)
        .mintOptionsPosition(qTokenPutAddress, ethers.BigNumber.from("2"));

      // the user's USDC balance should have decreased
      expect(await USDC.balanceOf(await secondAccount.getAddress())).to.equal(
        ethers.utils.parseUnits("1200", "6")
      );

      // the controller should have received the user's collateral
      expect(await USDC.balanceOf(controller.address)).to.equal(
        ethers.utils.parseUnits("2800", "6")
      );
    });

    it("Users should be able to mint CALL options positions", async () => {
      await WETH.connect(admin).mint(
        await secondAccount.getAddress(),
        ethers.utils.parseEther("6")
      );

      await WETH.connect(secondAccount).approve(
        controller.address,
        ethers.utils.parseEther("4")
      );

      await expect(
        controller
          .connect(secondAccount)
          .mintOptionsPosition(qTokenCallAddress, ethers.BigNumber.from("4"))
      )
        .to.emit(controller, "OptionsPositionMinted")
        .withArgs(
          await secondAccount.getAddress(),
          ethers.utils.parseEther("4")
        );

      const collateralTokenId = await optionsFactory.getTargetCollateralTokenId(
        WETH.address,
        USDC.address,
        ethers.constants.AddressZero,
        ethers.utils.parseUnits("2000", await USDC.decimals()),
        ethers.BigNumber.from(futureTimestamp),
        ethers.BigNumber.from("0"),
        true
      );

      expect(
        await collateralToken.balanceOf(
          await secondAccount.getAddress(),
          collateralTokenId
        )
      ).to.equal(ethers.utils.parseEther("4"));

      const QTokenABI = (await ethers.getContractFactory("QToken")).interface;

      const qToken = <QToken>(
        new ethers.Contract(qTokenCallAddress, QTokenABI, provider)
      );

      expect(await qToken.balanceOf(await secondAccount.getAddress())).to.equal(
        ethers.utils.parseEther("4")
      );
    });

    it("Users should be able to mint PUT options positions", async () => {
      await USDC.connect(admin).mint(
        await secondAccount.getAddress(),
        ethers.utils.parseUnits("8000", "6") // USDC has 6 decimals
      );

      await USDC.connect(secondAccount).approve(
        controller.address,
        ethers.utils.parseUnits("5600", "6")
      );

      await expect(
        controller
          .connect(secondAccount)
          .mintOptionsPosition(qTokenPutAddress, ethers.BigNumber.from("4"))
      )
        .to.emit(controller, "OptionsPositionMinted")
        .withArgs(
          await secondAccount.getAddress(),
          ethers.utils.parseEther("4")
        );

      const collateralTokenId = await optionsFactory.getTargetCollateralTokenId(
        WETH.address,
        USDC.address,
        ethers.constants.AddressZero,
        ethers.utils.parseUnits("1400", 6),
        ethers.BigNumber.from(futureTimestamp),
        ethers.BigNumber.from("0"),
        false
      );

      expect(
        await collateralToken.balanceOf(
          await secondAccount.getAddress(),
          collateralTokenId
        )
      ).to.equal(ethers.utils.parseEther("4"));

      const QTokenABI = (await ethers.getContractFactory("QToken")).interface;

      const qToken = <QToken>(
        new ethers.Contract(qTokenPutAddress, QTokenABI, provider)
      );

      expect(await qToken.balanceOf(await secondAccount.getAddress())).to.equal(
        ethers.utils.parseEther("4")
      );
    });
  });
});
