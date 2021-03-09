import { BigNumber, ContractInterface, Signer } from "ethers";
import { ethers, waffle } from "hardhat";
import { beforeEach, describe } from "mocha";
import ControllerJSON from "../artifacts/contracts/protocol/Controller.sol/Controller.json";
import { AssetsRegistry, OptionsFactory } from "../typechain";
import { CollateralToken } from "../typechain/CollateralToken";
import { Controller } from "../typechain/Controller";
import { MockERC20 } from "../typechain/MockERC20";
import { QToken } from "../typechain/QToken";
import { QuantConfig } from "../typechain/QuantConfig";
import { expect, provider } from "./setup";
import {
  deployAssetsRegistry,
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
  let assetsRegistry: AssetsRegistry;
  let futureTimestamp: number;
  let samplePutOptionParameters: optionParameters;
  let sampleCallOptionParameters: optionParameters;
  let qTokenPut1400: QToken;
  let qTokenCall2000: QToken;
  let QTokenInterface: ContractInterface;
  let mockERC20Interface: ContractInterface;

  const aMonth = 30 * 24 * 3600; // in seconds

  const getCollateralRequirement = async (
    qTokenShort: QToken,
    qTokenLong: QToken,
    optionsAmount: BigNumber
  ): Promise<[string, BigNumber]> => {
    if (await qTokenShort.isCall()) {
      const underlying = <MockERC20>(
        new ethers.Contract(
          await qTokenShort.underlyingAsset(),
          mockERC20Interface,
          provider
        )
      );
      const collateralAmount = optionsAmount.mul(
        ethers.BigNumber.from("10")
          .pow(await underlying.decimals())
          .div(ethers.BigNumber.from("10").pow(18))
      );
      return [underlying.address, collateralAmount];
    } else {
      const qTokenShortStrikePrice = await qTokenShort.strikePrice();
      let collateralPerOption = qTokenShortStrikePrice;

      if (qTokenLong.address !== ethers.constants.AddressZero) {
        const qTokenLongStrikePrice = await qTokenLong.strikePrice();
        collateralPerOption = qTokenShortStrikePrice.gt(qTokenLongStrikePrice)
          ? qTokenShortStrikePrice.sub(qTokenLongStrikePrice) // PUT Credit Spread
          : ethers.BigNumber.from("0"); // Put Debit Spread
      }
      const collateralAmount = optionsAmount
        .mul(collateralPerOption)
        .div(ethers.BigNumber.from("10").pow(18));
      return [await qTokenShort.strikeAsset(), collateralAmount];
    }
  };

  const testMintingOptions = async (
    qTokenShortAddress: string,
    optionsAmount: BigNumber,
    qTokenLongAddress: string = ethers.constants.AddressZero
  ) => {
    const qTokenShort = <QToken>(
      new ethers.Contract(qTokenShortAddress, QTokenInterface, provider)
    );

    const qTokenLong = <QToken>(
      new ethers.Contract(qTokenLongAddress, QTokenInterface, provider)
    );
    const underlying = <MockERC20>(
      new ethers.Contract(
        await qTokenShort.underlyingAsset(),
        mockERC20Interface,
        provider
      )
    );

    const [collateral, collateralAmount] = await getCollateralRequirement(
      qTokenShort,
      qTokenLong,
      optionsAmount
    );

    expect(
      await controller.getCollateralRequirement(
        qTokenShort.address,
        qTokenLong.address,
        optionsAmount
      )
    ).to.eql([collateral, collateralAmount]);

    // user should have 0 underlying initially
    expect(
      await underlying.balanceOf(await secondAccount.getAddress())
    ).to.equal(ethers.BigNumber.from("0"));

    if (qTokenLongAddress === ethers.constants.AddressZero) {
      // mint required collateral to the user account
      if ((await qTokenShort.isCall()) === true) {
        await WETH.connect(admin).mint(
          await secondAccount.getAddress(),
          optionsAmount
        );

        expect(await WETH.balanceOf(await secondAccount.getAddress())).to.equal(
          optionsAmount
        );

        await WETH.connect(secondAccount).approve(
          controller.address,
          optionsAmount
        );

        await expect(
          controller
            .connect(secondAccount)
            .mintOptionsPosition(qTokenShortAddress, optionsAmount)
        )
          .to.emit(controller, "OptionsPositionMinted")
          .withArgs(
            await secondAccount.getAddress(),
            qTokenShortAddress,
            optionsAmount
          );

        expect(await WETH.balanceOf(await secondAccount.getAddress())).to.equal(
          ethers.BigNumber.from("0")
        );

        expect(await WETH.balanceOf(controller.address)).to.equal(
          optionsAmount
        );
      } else {
        const requiredCollateral = optionsAmount
          .mul(await qTokenShort.strikePrice())
          .div(ethers.BigNumber.from("1000000000000000000"));

        await USDC.connect(admin).mint(
          await secondAccount.getAddress(),
          requiredCollateral
        );

        expect(await USDC.balanceOf(await secondAccount.getAddress())).to.equal(
          requiredCollateral
        );

        await USDC.connect(secondAccount).approve(
          controller.address,
          requiredCollateral
        );

        await controller
          .connect(secondAccount)
          .mintOptionsPosition(qTokenShortAddress, optionsAmount);

        expect(await USDC.balanceOf(await secondAccount.getAddress())).to.equal(
          ethers.BigNumber.from("0")
        );

        expect(await USDC.balanceOf(controller.address)).to.equal(
          requiredCollateral
        );
      }

      // Check that the user received the QToken and the CollateralToken
      expect(
        await qTokenShort.balanceOf(await secondAccount.getAddress())
      ).to.equal(optionsAmount);

      const collateralTokenId = await optionsFactory.qTokenAddressToCollateralTokenId(
        qTokenShortAddress
      );

      expect(
        await collateralToken.balanceOf(
          await secondAccount.getAddress(),
          collateralTokenId
        )
      ).to.equal(optionsAmount);
    }
  };

  beforeEach(async () => {
    [admin, secondAccount] = await provider.getWallets();

    quantConfig = await deployQuantConfig(admin);

    WETH = await mockERC20(admin, "WETH", "Wrapped Ether");
    USDC = await mockERC20(admin, "USDC", "USD Coin", 6);
    collateralToken = await deployCollateralToken(admin, quantConfig);

    assetsRegistry = await deployAssetsRegistry(admin, quantConfig);

    await assetsRegistry
      .connect(admin)
      .addAsset(
        WETH.address,
        await WETH.name(),
        await WETH.symbol(),
        await WETH.decimals()
      );

    await assetsRegistry
      .connect(admin)
      .addAsset(
        USDC.address,
        await USDC.name(),
        await USDC.symbol(),
        await USDC.decimals()
      );

    QTokenInterface = (await ethers.getContractFactory("QToken")).interface;

    mockERC20Interface = (await ethers.getContractFactory("MockERC20"))
      .interface;

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
    const qTokenPut1400Address = await optionsFactory.getTargetQTokenAddress(
      ...samplePutOptionParameters
    );

    await optionsFactory
      .connect(secondAccount)
      .createOption(...samplePutOptionParameters);

    qTokenPut1400 = <QToken>(
      new ethers.Contract(qTokenPut1400Address, QTokenInterface, provider)
    );

    sampleCallOptionParameters = [
      WETH.address,
      USDC.address,
      ethers.constants.AddressZero,
      ethers.utils.parseUnits("2000", await USDC.decimals()),
      ethers.BigNumber.from(futureTimestamp),
      true,
    ];

    const qTokenCall2000Address = await optionsFactory.getTargetQTokenAddress(
      ...sampleCallOptionParameters
    );

    await optionsFactory
      .connect(secondAccount)
      .createOption(...sampleCallOptionParameters);

    qTokenCall2000 = <QToken>(
      new ethers.Contract(qTokenCall2000Address, QTokenInterface, provider)
    );

    controller = <Controller>(
      await deployContract(admin, ControllerJSON, [optionsFactory.address])
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
          .mintOptionsPosition(
            qTokenPut1400.address,
            ethers.BigNumber.from("10")
          )
      ).to.be.revertedWith("Controller: Cannot mint expired options");

      // Reset the Hardhat Network
      await provider.send("evm_revert", ["0x1"]);
    });

    it("Users should be able to mint CALL options positions", async () => {
      await testMintingOptions(
        qTokenCall2000.address,
        ethers.utils.parseEther("2")
      );
    });

    it("Users should be able to mint PUT options positions", async () => {
      await testMintingOptions(
        qTokenPut1400.address,
        ethers.utils.parseEther("2")
      );
    });
  });

  describe("mintSpread", () => {
    it("Should require the correct amount of collateral for a PUT Credit spread", async () => {
      const qTokenShort = qTokenPut1400;

      const qTokenPut400Parameters: optionParameters = [
        WETH.address,
        USDC.address,
        ethers.constants.AddressZero,
        ethers.utils.parseUnits("400", await USDC.decimals()),
        ethers.BigNumber.from(futureTimestamp),
        false,
      ];

      await optionsFactory
        .connect(admin)
        .createOption(...qTokenPut400Parameters);

      const qTokenLongAddress = await optionsFactory.getTargetQTokenAddress(
        ...qTokenPut400Parameters
      );

      const qTokenLong = <QToken>(
        new ethers.Contract(qTokenLongAddress, QTokenInterface, provider)
      );

      const [collateral, collateralAmount] = await getCollateralRequirement(
        qTokenShort,
        qTokenLong,
        ethers.utils.parseEther("2")
      );

      expect(collateral).to.equal(USDC.address);
      expect(collateralAmount).to.equal(ethers.utils.parseUnits("2000", "6"));
    });
  });
});
