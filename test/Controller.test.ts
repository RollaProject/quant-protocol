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
  let qTokenPut400: QToken;
  let qTokenCall2000: QToken;
  let QTokenInterface: ContractInterface;
  let mockERC20Interface: ContractInterface;
  let qTokenCall2880: QToken;
  let qTokenCall3520: QToken;

  const aMonth = 30 * 24 * 3600; // in seconds

  const getCollateralRequirement = async (
    qTokenToMint: QToken,
    qTokenForCollateral: QToken,
    optionsAmount: BigNumber
  ): Promise<[string, BigNumber]> => {
    let collateralPerOption;

    const qTokenToMintStrikePrice = await qTokenToMint.strikePrice();
    let qTokenForCollateralStrikePrice = ethers.BigNumber.from("0");
    if (qTokenForCollateral.address !== ethers.constants.AddressZero) {
      qTokenForCollateralStrikePrice = await qTokenForCollateral.strikePrice();
    }

    const underlying = <MockERC20>(
      new ethers.Contract(
        await qTokenToMint.underlyingAsset(),
        mockERC20Interface,
        provider
      )
    );

    if (await qTokenToMint.isCall()) {
      collateralPerOption = ethers.BigNumber.from("10").pow(
        await underlying.decimals()
      );

      if (qTokenForCollateral.address !== ethers.constants.AddressZero) {
        collateralPerOption = qTokenToMintStrikePrice.gt(
          qTokenForCollateralStrikePrice
        )
          ? ethers.BigNumber.from("0")
          : qTokenForCollateralStrikePrice
              .sub(qTokenToMintStrikePrice)
              .abs()
              .mul(ethers.BigNumber.from("10").pow(18))
              .div(qTokenForCollateralStrikePrice);
      }
    } else {
      collateralPerOption = qTokenToMintStrikePrice;

      if (qTokenForCollateral.address !== ethers.constants.AddressZero) {
        collateralPerOption = qTokenToMintStrikePrice.gt(
          qTokenForCollateralStrikePrice
        )
          ? qTokenToMintStrikePrice.sub(qTokenForCollateralStrikePrice) // PUT Credit Spread
          : ethers.BigNumber.from("0"); // Put Debit Spread
      }
    }
    const collateralAmount = optionsAmount
      .mul(collateralPerOption)
      .div(ethers.BigNumber.from("10").pow(18));

    return [
      (await qTokenToMint.isCall())
        ? underlying.address
        : await qTokenToMint.strikeAsset(),
      collateralAmount,
    ];
  };

  const testMintingOptions = async (
    qTokenToMintAddress: string,
    optionsAmount: BigNumber,
    qTokenForCollateralAddress: string = ethers.constants.AddressZero
  ) => {
    const qTokenToMint = <QToken>(
      new ethers.Contract(qTokenToMintAddress, QTokenInterface, provider)
    );

    const qTokenForCollateral = <QToken>(
      new ethers.Contract(qTokenForCollateralAddress, QTokenInterface, provider)
    );

    const [
      collateralAddress,
      collateralAmount,
    ] = await getCollateralRequirement(
      qTokenToMint,
      qTokenForCollateral,
      optionsAmount
    );

    expect(
      await controller.getCollateralRequirement(
        qTokenToMint.address,
        qTokenForCollateral.address,
        optionsAmount
      )
    ).to.eql([collateralAddress, collateralAmount]);

    // mint required collateral to the user account
    const collateral = collateralAddress === WETH.address ? WETH : USDC;

    expect(
      await collateral.balanceOf(await secondAccount.getAddress())
    ).to.equal(0);

    await collateral
      .connect(admin)
      .mint(await secondAccount.getAddress(), collateralAmount);

    expect(
      await collateral.balanceOf(await secondAccount.getAddress())
    ).to.equal(collateralAmount);

    // Approve the Controller to use the user's funds
    await collateral
      .connect(secondAccount)
      .approve(controller.address, collateralAmount);

    // Check if it's a spread or a single option
    if (qTokenForCollateralAddress === ethers.constants.AddressZero) {
      await expect(
        controller
          .connect(secondAccount)
          .mintOptionsPosition(qTokenToMintAddress, optionsAmount)
      )
        .to.emit(controller, "OptionsPositionMinted")
        .withArgs(
          await secondAccount.getAddress(),
          qTokenToMintAddress,
          optionsAmount
        );

      // Check that the user received the CollateralToken
      const collateralTokenId = await optionsFactory.qTokenAddressToCollateralTokenId(
        qTokenToMintAddress
      );

      expect(
        await collateralToken.balanceOf(
          await secondAccount.getAddress(),
          collateralTokenId
        )
      ).to.equal(optionsAmount);
    } else {
      // Mint the qTokenForCollateral to the user address
      expect(
        await qTokenForCollateral.balanceOf(await secondAccount.getAddress())
      ).to.equal(ethers.BigNumber.from("0"));

      await qTokenForCollateral
        .connect(admin)
        .mint(await secondAccount.getAddress(), optionsAmount);

      expect(
        await qTokenForCollateral.balanceOf(await secondAccount.getAddress())
      ).to.equal(optionsAmount);

      await expect(
        controller
          .connect(secondAccount)
          .mintSpread(
            qTokenToMintAddress,
            qTokenForCollateralAddress,
            optionsAmount
          )
      )
        .to.emit(controller, "SpreadMinted")
        .withArgs(
          await secondAccount.getAddress(),
          qTokenToMintAddress,
          qTokenForCollateralAddress,
          optionsAmount
        );

      expect(
        await qTokenForCollateral.balanceOf(await secondAccount.getAddress())
      ).to.equal(ethers.BigNumber.from("0"));

      // Check that the user received the CollateralToken
      const collateralTokenId = await collateralToken.getCollateralTokenId(
        qTokenToMintAddress,
        collateralAmount
      );

      expect(
        await collateralToken.balanceOf(
          await secondAccount.getAddress(),
          collateralTokenId
        )
      ).to.equal(collateralAmount);
    }

    expect(
      await collateral.balanceOf(await secondAccount.getAddress())
    ).to.equal(ethers.BigNumber.from("0"));

    expect(await collateral.balanceOf(controller.address)).to.equal(
      collateralAmount
    );

    // Check that the user received the QToken
    expect(
      await qTokenToMint.balanceOf(await secondAccount.getAddress())
    ).to.equal(optionsAmount);
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

    const qTokenCall2880Parameters: optionParameters = [
      WETH.address,
      USDC.address,
      ethers.constants.AddressZero,
      ethers.utils.parseUnits("2880", await USDC.decimals()),
      ethers.BigNumber.from(futureTimestamp),
      true,
    ];

    await optionsFactory
      .connect(secondAccount)
      .createOption(...qTokenCall2880Parameters);

    qTokenCall2880 = <QToken>(
      new ethers.Contract(
        await optionsFactory.getTargetQTokenAddress(
          ...qTokenCall2880Parameters
        ),
        QTokenInterface,
        provider
      )
    );

    const qTokenCall3520Parameters: optionParameters = [
      WETH.address,
      USDC.address,
      ethers.constants.AddressZero,
      ethers.utils.parseUnits("3520", await USDC.decimals()),
      ethers.BigNumber.from(futureTimestamp),
      true,
    ];

    await optionsFactory
      .connect(secondAccount)
      .createOption(...qTokenCall3520Parameters);

    qTokenCall3520 = <QToken>(
      new ethers.Contract(
        await optionsFactory.getTargetQTokenAddress(
          ...qTokenCall3520Parameters
        ),
        QTokenInterface,
        provider
      )
    );

    const qTokenPut400Parameters: optionParameters = [
      WETH.address,
      USDC.address,
      ethers.constants.AddressZero,
      ethers.utils.parseUnits("400", await USDC.decimals()),
      ethers.BigNumber.from(futureTimestamp),
      false,
    ];

    await optionsFactory
      .connect(secondAccount)
      .createOption(...qTokenPut400Parameters);

    qTokenPut400 = <QToken>(
      new ethers.Contract(
        await optionsFactory.getTargetQTokenAddress(...qTokenPut400Parameters),
        QTokenInterface,
        provider
      )
    );

    controller = <Controller>(
      await deployContract(admin, ControllerJSON, [optionsFactory.address])
    );

    await quantConfig.grantRole(
      await quantConfig.OPTIONS_CONTROLLER_ROLE(),
      controller.address
    );

    await quantConfig.connect(admin).setAssetsRegistry(assetsRegistry.address);
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
    it("Users should be able to create a PUT Credit spread", async () => {
      await testMintingOptions(
        qTokenPut1400.address,
        ethers.utils.parseEther("2"),
        qTokenPut400.address
      );
    });

    it("Users should be able to create a PUT Debit spread", async () => {
      await testMintingOptions(
        qTokenPut400.address,
        ethers.utils.parseEther("2"),
        qTokenPut1400.address
      );
    });

    it("Users should be able to create a CALL Credit Spread", async () => {
      await testMintingOptions(
        qTokenCall2880.address,
        ethers.utils.parseEther("1"),
        qTokenCall3520.address
      );
    });

    it("Users should be able to create a CALL Debit Spread", async () => {
      await testMintingOptions(
        qTokenCall3520.address,
        ethers.utils.parseEther("1"),
        qTokenCall2880.address
      );
    });
  });
});
