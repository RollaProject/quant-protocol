import { MockContract } from "ethereum-waffle";
import { BigNumber, ContractInterface, Signer } from "ethers";
import { ethers, waffle } from "hardhat";
import { beforeEach, describe } from "mocha";
import ControllerJSON from "../artifacts/contracts/protocol/Controller.sol/Controller.json";
import ORACLE_MANAGER from "../artifacts/contracts/protocol/pricing/oracle/ChainlinkOracleManager.sol/ChainlinkOracleManager.json";
import PriceRegistry from "../artifacts/contracts/protocol/pricing/PriceRegistry.sol/PriceRegistry.json";
import { AssetsRegistry, OptionsFactory, OracleRegistry } from "../typechain";
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
  deployOracleRegistry,
  deployQuantConfig,
  mockERC20,
} from "./testUtils";

const { deployContract, deployMockContract } = waffle;

type optionParameters = [string, string, string, BigNumber, BigNumber, boolean];

describe("Controller", () => {
  let controller: Controller;
  let quantConfig: QuantConfig;
  let collateralToken: CollateralToken;
  let timelockController: Signer;
  let secondAccount: Signer;
  let assetsRegistryManager: Signer;
  let collateralMinter: Signer;
  let optionsMinter: Signer;
  let collateralCreator: Signer;
  let oracleManagerAccount: Signer;
  let WETH: MockERC20;
  let USDC: MockERC20;
  let optionsFactory: OptionsFactory;
  let assetsRegistry: AssetsRegistry;
  let oracleRegistry: OracleRegistry;
  let mockOracleManager: MockContract;
  let mockOracleManagerTwo: MockContract;
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
  let mockPriceRegistry: MockContract;
  let nullQToken: QToken;
  let snapshotCounter = 1; // Snapshots start at 1

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
      .connect(assetsRegistryManager)
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
          .mintOptionsPosition(
            await secondAccount.getAddress(),
            qTokenToMintAddress,
            optionsAmount
          )
      )
        .to.emit(controller, "OptionsPositionMinted")
        .withArgs(
          await secondAccount.getAddress(),
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
        .connect(optionsMinter)
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

      const collateralTokenId = await collateralToken.getCollateralTokenId(
        qTokenToMintAddress,
        qTokenForCollateral.address
      );

      expect(
        await collateralToken.balanceOf(
          await secondAccount.getAddress(),
          collateralTokenId
        )
      ).to.equal(optionsAmount);
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

  const testClaimCollateral = async (
    qTokenShort: QToken,
    amountToClaim: BigNumber,
    expiryPrice: BigNumber,
    qTokenLong: QToken = <QToken>(
      new ethers.Contract(
        ethers.constants.AddressZero,
        QTokenInterface,
        provider
      )
    )
  ) => {
    await mockPriceRegistry.mock.hasSettlementPrice.returns(true);

    await mockPriceRegistry.mock.getSettlementPrice.returns(expiryPrice);

    const [
      collateralAddress,
      collateralRequirement,
    ] = await getCollateralRequirement(qTokenShort, qTokenLong, amountToClaim);

    const collateral = collateralAddress === WETH.address ? WETH : USDC;

    await collateral
      .connect(assetsRegistryManager)
      .mint(await secondAccount.getAddress(), collateralRequirement);

    let qTokenAsCollateral;
    let collateralRequiredForLong = ethers.BigNumber.from("0");

    if (qTokenLong.address === ethers.constants.AddressZero) {
      qTokenAsCollateral = ethers.constants.AddressZero;

      await collateral
        .connect(secondAccount)
        .approve(controller.address, collateralRequirement);

      await controller
        .connect(secondAccount)
        .mintOptionsPosition(
          await secondAccount.getAddress(),
          qTokenShort.address,
          amountToClaim
        );
    } else {
      qTokenAsCollateral = qTokenLong.address;

      collateralRequiredForLong = (
        await getCollateralRequirement(qTokenLong, nullQToken, amountToClaim)
      )[1];

      await collateral
        .connect(assetsRegistryManager)
        .mint(await secondAccount.getAddress(), collateralRequiredForLong);

      await collateral
        .connect(secondAccount)
        .approve(
          controller.address,
          collateralRequirement.add(collateralRequiredForLong)
        );

      await controller
        .connect(secondAccount)
        .mintOptionsPosition(
          await secondAccount.getAddress(),
          qTokenLong.address,
          amountToClaim
        );

      await controller
        .connect(secondAccount)
        .mintSpread(qTokenShort.address, qTokenLong.address, amountToClaim);
    }

    const collateralTokenId = await collateralToken.getCollateralTokenId(
      qTokenShort.address,
      qTokenAsCollateral
    );

    // Take a snapshot of the Hardhat Network
    await provider.send("evm_snapshot", []);

    // Increase time to one hour past the expiry
    await provider.send("evm_mine", [futureTimestamp + 3600]);

    const [payoutFromShort, payoutAsset] = await getPayout(
      qTokenShort,
      amountToClaim,
      expiryPrice
    );

    const payoutFromLong =
      qTokenLong.address !== ethers.constants.AddressZero
        ? (await getPayout(qTokenLong, amountToClaim, expiryPrice))[0]
        : ethers.BigNumber.from("0");

    const claimableCollateral = payoutFromLong
      .add(collateralRequirement)
      .sub(payoutFromShort);

    await controller
      .connect(secondAccount)
      .claimCollateral(collateralTokenId, amountToClaim);

    expect(
      await payoutAsset.balanceOf(await secondAccount.getAddress())
    ).to.equal(claimableCollateral);

    expect(await payoutAsset.balanceOf(controller.address)).to.equal(
      collateralRequirement
        .add(collateralRequiredForLong)
        .sub(claimableCollateral)
    );

    const strikePriceString = (await qTokenShort.strikePrice()).div(
      ethers.BigNumber.from("10").pow(await USDC.decimals())
    );
    const qTokenShortString = `${strikePriceString}${
      (await qTokenShort.isCall()) ? "CALL" : "PUT"
    }`;

    const collateralRequirementString =
      parseInt(collateralRequirement.toString()) /
      10 ** (await collateral.decimals());

    const expiryPriceString = expiryPrice.div(
      ethers.BigNumber.from("10").pow(await USDC.decimals())
    );

    const payoutFromShortString =
      parseInt(payoutFromShort.toString()) /
      10 ** (await payoutAsset.decimals());

    const claimableCollateralString = `${
      parseInt(claimableCollateral.toString()) /
      10 ** (await collateral.decimals())
    } ${payoutAsset.address === USDC.address ? "USDC" : "WETH"}`;

    const qTokenLongStrikePriceString =
      qTokenLong.address !== ethers.constants.AddressZero
        ? (await qTokenLong.strikePrice())
            .div(ethers.BigNumber.from("10").pow(await USDC.decimals()))
            .toString()
        : "0";

    console.log(
      `${qTokenShortString} -> CollateralToken(${qTokenShortString}, ${qTokenLongStrikePriceString}) costing ${collateralRequirementString} ${
        collateral.address === USDC.address ? "USDC" : "WETH"
      }`
    );
    console.log(
      `Expired at $${expiryPriceString}. Exercised for ${payoutFromShortString} ${
        payoutAsset.address === USDC.address ? "USDC" : "WETH"
      } so the user is entitled to ${claimableCollateralString}`
    );
  };

  const getPayout = async (
    qToken: QToken,
    amount: BigNumber,
    expiryPrice: BigNumber
  ): Promise<[BigNumber, MockERC20]> => {
    const strikePrice = await qToken.strikePrice();
    const underlyingDecimals = await WETH.decimals();
    const optionsDecimals = 18;

    let payoutAmount: BigNumber;
    let payoutToken: MockERC20;

    if (await qToken.isCall()) {
      payoutAmount = expiryPrice.gt(strikePrice)
        ? expiryPrice
            .sub(strikePrice)
            .mul(amount)
            .div(expiryPrice)
            .mul(ethers.BigNumber.from("10").pow(underlyingDecimals))
            .div(ethers.BigNumber.from("10").pow(optionsDecimals))
        : ethers.BigNumber.from("0");

      payoutToken = WETH;
    } else {
      payoutAmount = strikePrice.gt(expiryPrice)
        ? strikePrice
            .sub(expiryPrice)
            .mul(amount)
            .div(ethers.BigNumber.from("10").pow(optionsDecimals))
        : ethers.BigNumber.from("0");

      payoutToken = USDC;
    }

    return [payoutAmount, payoutToken];
  };

  const revertFromSnapshot = async () => {
    // Reset the Hardhat Network
    await provider.send("evm_revert", [
      `0x${(snapshotCounter++).toString(16)}`,
    ]);
  };

  beforeEach(async () => {
    [
      timelockController,
      secondAccount,
      assetsRegistryManager,
      collateralMinter,
      optionsMinter,
      collateralCreator,
      oracleManagerAccount,
    ] = await provider.getWallets();

    quantConfig = await deployQuantConfig(timelockController, [
      {
        addresses: [await assetsRegistryManager.getAddress()],
        role: ethers.utils.id("ASSET_REGISTRY_MANAGER_ROLE"),
      },
      {
        addresses: [
          await collateralMinter.getAddress(),
          await assetsRegistryManager.getAddress(),
        ],
        role: ethers.utils.id("COLLATERAL_MINTER_ROLE"),
      },
      {
        addresses: [await optionsMinter.getAddress()],
        role: ethers.utils.id("OPTIONS_MINTER_ROLE"),
      },
      {
        addresses: [await collateralCreator.getAddress()],
        role: ethers.utils.id("COLLATERAL_CREATOR_ROLE"),
      },
      {
        addresses: [await oracleManagerAccount.getAddress()],
        role: ethers.utils.id("ORACLE_MANAGER_ROLE"),
      },
    ]);

    WETH = await mockERC20(assetsRegistryManager, "WETH", "Wrapped Ether");
    USDC = await mockERC20(assetsRegistryManager, "USDC", "USD Coin", 6);
    collateralToken = await deployCollateralToken(
      timelockController,
      quantConfig
    );

    assetsRegistry = await deployAssetsRegistry(
      timelockController,
      quantConfig
    );

    oracleRegistry = await deployOracleRegistry(
      timelockController,
      quantConfig
    );

    mockOracleManager = await deployMockContract(
      timelockController,
      ORACLE_MANAGER.abi
    );

    mockOracleManagerTwo = await deployMockContract(
      timelockController,
      ORACLE_MANAGER.abi
    );

    await assetsRegistry
      .connect(assetsRegistryManager)
      .addAsset(
        WETH.address,
        await WETH.name(),
        await WETH.symbol(),
        await WETH.decimals(),
        ethers.BigNumber.from("1000")
      );

    await assetsRegistry
      .connect(assetsRegistryManager)
      .addAsset(
        USDC.address,
        await USDC.name(),
        await USDC.symbol(),
        await USDC.decimals(),
        ethers.BigNumber.from("1000")
      );

    QTokenInterface = (await ethers.getContractFactory("QToken")).interface;

    mockERC20Interface = (await ethers.getContractFactory("MockERC20"))
      .interface;

    optionsFactory = await deployOptionsFactory(
      timelockController,
      quantConfig,
      collateralToken
    );

    // 30 days from now
    futureTimestamp = Math.floor(Date.now() / 1000) + aMonth;

    samplePutOptionParameters = [
      WETH.address,
      USDC.address,
      mockOracleManager.address,
      ethers.utils.parseUnits("1400", await USDC.decimals()),
      ethers.BigNumber.from(futureTimestamp),
      false,
    ];
    const qTokenPut1400Address = await optionsFactory.getTargetQTokenAddress(
      ...samplePutOptionParameters
    );

    await quantConfig
      .connect(timelockController)
      .grantRole(
        ethers.utils.id("COLLATERAL_CREATOR_ROLE"),
        optionsFactory.address
      );

    await quantConfig
      .connect(timelockController)
      .setRoleAdmin(
        await quantConfig.PRICE_SUBMITTER_ROLE(),
        await quantConfig.PRICE_SUBMITTER_ROLE_ADMIN()
      );

    await quantConfig
      .connect(timelockController)
      .grantRole(
        await quantConfig.PRICE_SUBMITTER_ROLE_ADMIN(),
        oracleRegistry.address
      );

    await oracleRegistry
      .connect(oracleManagerAccount)
      .addOracle(mockOracleManager.address);

    await oracleRegistry
      .connect(oracleManagerAccount)
      .addOracle(mockOracleManagerTwo.address);

    await oracleRegistry
      .connect(oracleManagerAccount)
      .activateOracle(mockOracleManager.address);

    await oracleRegistry
      .connect(oracleManagerAccount)
      .activateOracle(mockOracleManagerTwo.address);

    //Note: returning any address here to show existence of the oracle
    await mockOracleManager.mock.getAssetOracle.returns(
      mockOracleManager.address
    );

    //Note: returning any address here to show existence of the oracle
    await mockOracleManagerTwo.mock.getAssetOracle.returns(
      mockOracleManagerTwo.address
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
      mockOracleManager.address,
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
      mockOracleManager.address,
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
      mockOracleManager.address,
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
      mockOracleManager.address,
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

    nullQToken = <QToken>(
      new ethers.Contract(
        ethers.constants.AddressZero,
        QTokenInterface,
        provider
      )
    );

    controller = <Controller>(
      await deployContract(timelockController, ControllerJSON, [
        optionsFactory.address,
      ])
    );

    await quantConfig
      .connect(timelockController)
      .grantRole(ethers.utils.id("OPTIONS_MINTER_ROLE"), controller.address);

    await quantConfig
      .connect(timelockController)
      .grantRole(ethers.utils.id("OPTIONS_BURNER_ROLE"), controller.address);

    await quantConfig
      .connect(timelockController)
      .grantRole(
        ethers.utils.id("COLLATERAL_CREATOR_ROLE"),
        controller.address
      );

    await quantConfig
      .connect(timelockController)
      .grantRole(ethers.utils.id("COLLATERAL_MINTER_ROLE"), controller.address);

    await quantConfig
      .connect(timelockController)
      .grantRole(ethers.utils.id("COLLATERAL_BURNER_ROLE"), controller.address);

    await quantConfig
      .connect(timelockController)
      .setAssetsRegistry(assetsRegistry.address);

    mockPriceRegistry = await deployMockContract(
      timelockController,
      PriceRegistry.abi
    );

    await quantConfig
      .connect(timelockController)
      .setPriceRegistry(mockPriceRegistry.address);
  });

  describe("mintOptionsPosition", () => {
    it("Should revert when trying to mint an option which has an oracle which is deactivated", async () => {
      await oracleRegistry
        .connect(oracleManagerAccount)
        .deactivateOracle(mockOracleManager.address);

      await expect(
        controller
          .connect(secondAccount)
          .mintOptionsPosition(
            await secondAccount.getAddress(),
            qTokenCall2000.address,
            ethers.BigNumber.from("10")
          )
      ).to.be.revertedWith(
        "Controller: Can't mint an options position as the oracle is inactive"
      );
    });

    it("Should revert when trying to mint a non-existent option", async () => {
      await expect(
        controller
          .connect(secondAccount)
          .mintOptionsPosition(
            await secondAccount.getAddress(),
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
          .connect(secondAccount)
          .mintOptionsPosition(
            await secondAccount.getAddress(),
            qTokenPut1400.address,
            ethers.BigNumber.from("10")
          )
      ).to.be.revertedWith("Controller: Cannot mint expired options");

      await revertFromSnapshot();
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

    // TODO:
    // eslint-disable-next-line @typescript-eslint/no-empty-function
    // it("Users should be able to mint options to a different address", async () => {});
  });

  describe("mintSpread", () => {
    it("Should revert when trying to create spreads from options with different oracles", async () => {
      const qTokenParams: optionParameters = [
        WETH.address,
        USDC.address,
        mockOracleManager.address,
        ethers.utils.parseUnits("1400", await USDC.decimals()),
        ethers.BigNumber.from(futureTimestamp + 3600 * 24 * 30),
        false,
      ];

      const qTokenParamsDifferentOracle: optionParameters = [...qTokenParams];

      qTokenParamsDifferentOracle[2] = mockOracleManagerTwo.address;

      const qTokenOracleOne = await optionsFactory.getTargetQTokenAddress(
        ...qTokenParams
      );

      const qTokenOracleTwo = await optionsFactory.getTargetQTokenAddress(
        ...qTokenParamsDifferentOracle
      );

      await optionsFactory.connect(secondAccount).createOption(...qTokenParams);

      await optionsFactory
        .connect(secondAccount)
        .createOption(...qTokenParamsDifferentOracle);

      await expect(
        controller
          .connect(secondAccount)
          .mintSpread(
            qTokenOracleOne,
            qTokenOracleTwo,
            ethers.utils.parseEther("1")
          )
      ).to.be.revertedWith(
        "Controller: Can't create spreads from options with different oracles"
      );
    });

    it("Should revert when trying to create spreads from options with different expiries", async () => {
      const qTokenParams: optionParameters = [
        WETH.address,
        USDC.address,
        mockOracleManager.address,
        ethers.utils.parseUnits("1400", await USDC.decimals()),
        ethers.BigNumber.from(futureTimestamp + 3600 * 24 * 30),
        false,
      ];
      const qTokenPutDifferentExpiry = await optionsFactory.getTargetQTokenAddress(
        ...qTokenParams
      );

      await optionsFactory.connect(secondAccount).createOption(...qTokenParams);

      await expect(
        controller
          .connect(secondAccount)
          .mintSpread(
            qTokenPutDifferentExpiry,
            qTokenPut1400.address,
            ethers.utils.parseEther("1")
          )
      ).to.be.revertedWith(
        "Controller: Can't create spreads from options with different expiries"
      );
    });

    it("Should revert when trying to create spreads from options with different underlying assets", async () => {
      const qTokenParams: optionParameters = [
        USDC.address,
        WETH.address,
        mockOracleManager.address,
        ethers.utils.parseUnits("5000", await USDC.decimals()),
        ethers.BigNumber.from(futureTimestamp),
        true,
      ];
      const qTokenCallDifferentUnderlying = await optionsFactory.getTargetQTokenAddress(
        ...qTokenParams
      );

      await optionsFactory.createOption(...qTokenParams);

      await expect(
        controller
          .connect(secondAccount)
          .mintSpread(
            qTokenCallDifferentUnderlying,
            qTokenCall3520.address,
            ethers.utils.parseEther("1")
          )
      ).to.be.revertedWith(
        "Controller: Can't create spreads from options with different underlying assets"
      );
    });

    // TODO: Test the following case
    // it("Should revert when trying to create spreads from options with different underlying assets", async () => {});

    it("Users should be able to create a PUT Credit spread", async () => {
      await testMintingOptions(
        qTokenPut1400.address,
        ethers.utils.parseEther("1"),
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

    it("Spreads should be created correctly when the CollateralToken had already been created before", async () => {
      await collateralToken
        .connect(collateralCreator)
        .createCollateralToken(qTokenCall2000.address, qTokenCall2880.address);

      await testMintingOptions(
        qTokenCall2000.address,
        ethers.utils.parseEther("1"),
        qTokenCall2880.address
      );
    });
  });

  describe("exercise", () => {
    it("Should revert when trying to exercise a non-expired option", async () => {
      await expect(
        controller
          .connect(secondAccount)
          .exercise(qTokenPut1400.address, ethers.utils.parseEther("1"))
      ).to.be.revertedWith(
        "Controller: Can not exercise options before their expiry"
      );
    });

    it("Should revert when trying to exercise unsettled options", async () => {
      // Take a snapshot of the Hardhat Network
      await provider.send("evm_snapshot", []);

      // Increase time to one hour past the expiry
      await provider.send("evm_mine", [futureTimestamp + 3600]);

      await mockPriceRegistry.mock.hasSettlementPrice.returns(false);

      await expect(
        controller
          .connect(secondAccount)
          .exercise(qTokenPut1400.address, ethers.utils.parseEther("1"))
      ).to.be.revertedWith("Controller: Cannot exercise unsettled options");

      await revertFromSnapshot();
    });

    it("Users should be able to exercise PUT options", async () => {
      // Take a snapshot of the Hardhat Network
      await provider.send("evm_snapshot", []);

      // Increase time to one hour past the expiry
      await provider.send("evm_mine", [futureTimestamp + 3600]);

      await mockPriceRegistry.mock.hasSettlementPrice.returns(true);

      await mockPriceRegistry.mock.getSettlementPrice.returns(
        ethers.utils.parseUnits("1200", await USDC.decimals())
      );

      // Mint options to the user
      const optionsAmount = ethers.utils.parseEther("1");
      const qTokenToExercise = qTokenPut1400;
      await qTokenToExercise
        .connect(optionsMinter)
        .mint(await secondAccount.getAddress(), optionsAmount);

      expect(await USDC.balanceOf(await secondAccount.getAddress())).to.equal(
        ethers.BigNumber.from("0")
      );

      expect(
        await qTokenToExercise.balanceOf(await secondAccount.getAddress())
      ).to.equal(optionsAmount);

      const payoutAmount = (
        await controller.getPayout(qTokenToExercise.address, optionsAmount)
      ).payoutAmount;

      // Mint USDC to the Controller so it can pay the user
      await USDC.connect(timelockController).mint(
        controller.address,
        payoutAmount
      );
      expect(await USDC.balanceOf(controller.address)).to.equal(payoutAmount);

      await expect(
        controller
          .connect(secondAccount)
          .exercise(qTokenToExercise.address, optionsAmount)
      )
        .to.emit(controller, "OptionsExercised")
        .withArgs(
          await secondAccount.getAddress(),
          qTokenToExercise.address,
          optionsAmount,
          payoutAmount,
          USDC.address
        );

      expect(await USDC.balanceOf(await secondAccount.getAddress())).to.equal(
        payoutAmount
      );
      expect(await USDC.balanceOf(controller.address)).to.equal(
        ethers.BigNumber.from("0")
      );
      expect(
        await qTokenToExercise.balanceOf(await secondAccount.getAddress())
      ).to.equal(ethers.BigNumber.from("0"));

      await revertFromSnapshot();
    });

    it("Users should be able to exercise CALL options", async () => {
      // Take a snapshot of the Hardhat Network
      await provider.send("evm_snapshot", []);

      // Increase time to one hour past the expiry
      await provider.send("evm_mine", [futureTimestamp + 3600]);

      await mockPriceRegistry.mock.hasSettlementPrice.returns(true);

      await mockPriceRegistry.mock.getSettlementPrice.returns(
        ethers.utils.parseUnits("2500", await USDC.decimals())
      );

      // Mint options to the user
      const optionsAmount = ethers.utils.parseEther("2");
      const qTokenToExercise = qTokenCall2000;
      await qTokenToExercise
        .connect(optionsMinter)
        .mint(await secondAccount.getAddress(), optionsAmount);

      expect(await WETH.balanceOf(await secondAccount.getAddress())).to.equal(
        ethers.BigNumber.from("0")
      );

      expect(
        await qTokenToExercise.balanceOf(await secondAccount.getAddress())
      ).to.equal(optionsAmount);

      const payoutAmount = (
        await controller.getPayout(qTokenToExercise.address, optionsAmount)
      ).payoutAmount;

      // Mint WETH to the Controller so it can pay the user
      await WETH.connect(assetsRegistryManager).mint(
        controller.address,
        payoutAmount
      );
      expect(await WETH.balanceOf(controller.address)).to.equal(payoutAmount);

      await expect(
        controller.connect(secondAccount).exercise(qTokenToExercise.address, 0)
      )
        .to.emit(controller, "OptionsExercised")
        .withArgs(
          await secondAccount.getAddress(),
          qTokenToExercise.address,
          optionsAmount,
          payoutAmount,
          WETH.address
        );

      expect(await WETH.balanceOf(await secondAccount.getAddress())).to.equal(
        payoutAmount
      );
      expect(await WETH.balanceOf(controller.address)).to.equal(
        ethers.BigNumber.from("0")
      );
      expect(
        await qTokenToExercise.balanceOf(await secondAccount.getAddress())
      ).to.equal(ethers.BigNumber.from("0"));

      await revertFromSnapshot();
    });

    it("Should revert when a user tries to exercise an amount of options that exceeds his balance", async () => {
      // Take a snapshot of the Hardhat Network
      await provider.send("evm_snapshot", []);

      // Increase time to one hour past the expiry
      await provider.send("evm_mine", [futureTimestamp + 3600]);

      await mockPriceRegistry.mock.hasSettlementPrice.returns(true);

      await mockPriceRegistry.mock.getSettlementPrice.returns(
        ethers.utils.parseUnits("200", await USDC.decimals())
      );

      await expect(
        controller
          .connect(secondAccount)
          .exercise(qTokenPut1400.address, ethers.utils.parseEther("1"))
      ).to.be.revertedWith("ERC20: burn amount exceeds balance");

      await revertFromSnapshot();
    });

    it("Burns the QTokens but don't transfer anything when options expire OTM", async () => {
      // Take a snapshot of the Hardhat Network
      await provider.send("evm_snapshot", []);

      // Increase time to one hour past the expiry
      await provider.send("evm_mine", [futureTimestamp + 3600]);

      await mockPriceRegistry.mock.hasSettlementPrice.returns(true);

      await mockPriceRegistry.mock.getSettlementPrice.returns(
        ethers.utils.parseUnits("1800", await USDC.decimals())
      );

      // Mint options to the user
      const optionsAmount = ethers.utils.parseEther("3");
      const qTokenToExercise = qTokenCall2000;
      await qTokenToExercise
        .connect(optionsMinter)
        .mint(await secondAccount.getAddress(), optionsAmount);

      await controller
        .connect(secondAccount)
        .exercise(qTokenToExercise.address, optionsAmount);

      expect(
        await qTokenToExercise.balanceOf(await secondAccount.getAddress())
      ).to.equal(ethers.BigNumber.from("0"));

      expect(await WETH.balanceOf(await secondAccount.getAddress())).to.equal(
        ethers.BigNumber.from("0")
      );

      await revertFromSnapshot();
    });
  });

  describe("claimCollateral", () => {
    it("Should revert when trying to claim collateral from an invalid CollateralToken", async () => {
      await expect(
        controller
          .connect(secondAccount)
          .claimCollateral(
            ethers.BigNumber.from("123"),
            ethers.utils.parseEther("1")
          )
      ).to.be.revertedWith(
        "Controller: Can not claim collateral from non-existing option"
      );
    });

    it("Should revert when trying to claim collateral from options before their expiry", async () => {
      await expect(
        controller
          .connect(secondAccount)
          .claimCollateral(
            await collateralToken.getCollateralTokenId(
              qTokenPut400.address,
              ethers.constants.AddressZero
            ),
            ethers.utils.parseEther("1")
          )
      ).to.be.revertedWith(
        "Controller: Can not claim collateral from options before their expiry"
      );
    });

    it("Should revert when trying to claim collateral from options before their expiry price is settled", async () => {
      // Take a snapshot of the Hardhat Network
      await provider.send("evm_snapshot", []);

      // Increase time to one hour past the expiry
      await provider.send("evm_mine", [futureTimestamp + 3600]);

      await mockPriceRegistry.mock.hasSettlementPrice.returns(false);

      await expect(
        controller
          .connect(secondAccount)
          .claimCollateral(
            await collateralToken.getCollateralTokenId(
              qTokenPut400.address,
              ethers.constants.AddressZero
            ),
            ethers.utils.parseEther("1")
          )
      ).to.be.revertedWith(
        "Controller: Can not claim collateral before option is settled"
      );

      await revertFromSnapshot();
    });

    it("Users should be able to claim collateral from PUT options that expired ITM", async () => {
      const expiryPrice = ethers.utils.parseUnits("300", await USDC.decimals());

      await testClaimCollateral(
        qTokenPut400,
        ethers.utils.parseEther("1"),
        expiryPrice
      );

      await revertFromSnapshot();
    });

    it("Users should be able to claim collateral from PUT options that expired OTM", async () => {
      const expiryPrice = ethers.utils.parseUnits("500", await USDC.decimals());

      await testClaimCollateral(
        qTokenPut400,
        ethers.utils.parseEther("1"),
        expiryPrice
      );

      await revertFromSnapshot();
    });

    it("Users should be able to claim collateral from PUT options that expired ATM", async () => {
      const expiryPrice = ethers.utils.parseUnits("400", await USDC.decimals());

      await testClaimCollateral(
        qTokenPut400,
        ethers.utils.parseEther("1"),
        expiryPrice
      );

      await revertFromSnapshot();
    });

    it("Users should be able to claim collateral from CALL options that expired ITM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "2500",
        await USDC.decimals()
      );

      await testClaimCollateral(
        qTokenCall2000,
        ethers.utils.parseEther("1"),
        expiryPrice
      );

      await revertFromSnapshot();
    });

    it("Users should be able to claim collateral from CALL options that expired OTM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "1800",
        await USDC.decimals()
      );

      await testClaimCollateral(
        qTokenCall2000,
        ethers.utils.parseEther("1"),
        expiryPrice
      );

      await revertFromSnapshot();
    });

    it("Users should be able to claim collateral from CALL options that expired ATM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "2000",
        await USDC.decimals()
      );

      await testClaimCollateral(
        qTokenCall2000,
        ethers.utils.parseEther("1"),
        expiryPrice
      );

      await revertFromSnapshot();
    });

    it("Users should be able to claim collateral from PUT Credit Spreads that expired ITM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "1100",
        await USDC.decimals()
      );

      await testClaimCollateral(
        qTokenPut1400,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenPut400
      );

      await revertFromSnapshot();
    });

    it("PUT Credit Spreads that expired ITM and below the coverage of the spread CollateralToken", async () => {
      const expiryPrice = ethers.utils.parseUnits("300", await USDC.decimals());

      await testClaimCollateral(
        qTokenPut1400,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenPut400
      );

      expect(await USDC.balanceOf(await secondAccount.getAddress())).to.equal(
        ethers.BigNumber.from("0")
      );

      await revertFromSnapshot();
    });

    it("Users should be able to claim collateral from PUT Credit Spreads that expired OTM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "1800",
        await USDC.decimals()
      );

      await testClaimCollateral(
        qTokenPut1400,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenPut400
      );

      await revertFromSnapshot();
    });

    it("Users should be able to claim collateral from PUT Credit Spreads that expired ATM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "1400",
        await USDC.decimals()
      );

      await testClaimCollateral(
        qTokenPut1400,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenPut400
      );

      await revertFromSnapshot();
    });

    it("Users should be able to claim collateral from PUT Debit Spreads that expired ITM", async () => {
      const expiryPrice = ethers.utils.parseUnits("200", await USDC.decimals());

      await testClaimCollateral(
        qTokenPut400,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenPut1400
      );

      await revertFromSnapshot();
    });

    it("Users should be able to claim collateral from PUT Debit Spreads that expired OTM", async () => {
      const expiryPrice = ethers.utils.parseUnits("600", await USDC.decimals());

      await testClaimCollateral(
        qTokenPut400,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenPut1400
      );

      await revertFromSnapshot();
    });

    it("Users should be able to claim collateral from PUT Debit Spreads that expired ATM", async () => {
      const expiryPrice = ethers.utils.parseUnits("400", await USDC.decimals());

      await testClaimCollateral(
        qTokenPut400,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenPut1400
      );

      await revertFromSnapshot();
    });

    it("Users should be able to claim collateral from CALL Credit Spreads that expired ITM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "3200",
        await USDC.decimals()
      );

      await testClaimCollateral(
        qTokenCall3520,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenCall3520
      );

      await revertFromSnapshot();
    });

    it("Users should be able to claim collateral from CALL Credit Spreads that expired OTM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "2600",
        await USDC.decimals()
      );

      await testClaimCollateral(
        qTokenCall2880,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenCall3520
      );

      await revertFromSnapshot();
    });

    it("Users should be able to claim collateral from CALL Credit Spreads that expired ATM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "2880",
        await USDC.decimals()
      );

      await testClaimCollateral(
        qTokenCall2880,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenCall3520
      );

      await revertFromSnapshot();
    });

    it("CALL Credit Spreads that expired ITM, at the strike price of the long option", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "3520",
        await USDC.decimals()
      );

      await testClaimCollateral(
        qTokenCall2880,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenCall3520
      );

      expect(await WETH.balanceOf(await secondAccount.getAddress())).to.equal(
        ethers.BigNumber.from("0")
      );

      await revertFromSnapshot();
    });

    it("Users should be able to claim collateral from CALL Debit Spreads that expired ITM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "4000",
        await USDC.decimals()
      );

      await testClaimCollateral(
        qTokenCall3520,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenCall2880
      );

      await revertFromSnapshot();
    });

    it("Users should be able to claim collateral from CALL Debit Spreads that expired OTM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "3000",
        await USDC.decimals()
      );

      await testClaimCollateral(
        qTokenCall3520,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenCall2880
      );

      await revertFromSnapshot();
    });

    it("Users should be able to claim collateral from CALL Debit Spreads that expired ATM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "3520",
        await USDC.decimals()
      );

      await testClaimCollateral(
        qTokenCall3520,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenCall2880
      );

      await revertFromSnapshot();
    });
  });

  describe("neutralizePosition", () => {
    it("Should revert when users try to neutralize more options than they have", async () => {
      await expect(
        controller
          .connect(secondAccount)
          .neutralizePosition(
            await collateralToken.getCollateralTokenId(
              qTokenCall3520.address,
              ethers.constants.AddressZero
            ),
            ethers.utils.parseEther("4")
          )
      ).to.be.revertedWith("Controller: Tried to neutralize more than balance");
    });

    it("Users should be able to neutralize some of their position", async () => {
      const optionsAmount = ethers.utils.parseEther("5");

      const [, collateralRequirement] = await getCollateralRequirement(
        qTokenPut1400,
        nullQToken,
        optionsAmount
      );

      await USDC.connect(assetsRegistryManager).mint(
        await secondAccount.getAddress(),
        collateralRequirement
      );

      await USDC.connect(secondAccount).approve(
        controller.address,
        collateralRequirement
      );

      await controller
        .connect(secondAccount)
        .mintOptionsPosition(
          await secondAccount.getAddress(),
          qTokenPut1400.address,
          optionsAmount
        );

      const collateralTokenId = await collateralToken.getCollateralTokenId(
        qTokenPut1400.address,
        ethers.constants.AddressZero
      );
      const amountToNeutralize = ethers.utils.parseEther("3");

      await controller
        .connect(secondAccount)
        .neutralizePosition(collateralTokenId, amountToNeutralize);

      expect(
        await qTokenPut1400.balanceOf(await secondAccount.getAddress())
      ).to.equal(optionsAmount.sub(amountToNeutralize));

      expect(
        await collateralToken.balanceOf(
          await secondAccount.getAddress(),
          collateralTokenId
        )
      ).to.equal(optionsAmount.sub(amountToNeutralize));
    });

    it("Users should be able to neutralize all of their position, and get the long QToken back from a spread", async () => {
      const optionsAmount = ethers.utils.parseEther("5");

      const [, spreadCollateralRequirement] = await getCollateralRequirement(
        qTokenPut1400,
        qTokenPut400,
        optionsAmount
      );

      const [, longCollateralRequirement] = await getCollateralRequirement(
        qTokenPut400,
        nullQToken,
        optionsAmount
      );

      await USDC.connect(assetsRegistryManager).mint(
        await secondAccount.getAddress(),
        spreadCollateralRequirement.add(longCollateralRequirement)
      );

      await USDC.connect(secondAccount).approve(
        controller.address,
        spreadCollateralRequirement.add(longCollateralRequirement)
      );

      await controller
        .connect(secondAccount)
        .mintOptionsPosition(
          await secondAccount.getAddress(),
          qTokenPut400.address,
          optionsAmount
        );

      await controller
        .connect(secondAccount)
        .mintSpread(qTokenPut1400.address, qTokenPut400.address, optionsAmount);

      const collateralTokenId = await collateralToken.getCollateralTokenId(
        qTokenPut1400.address,
        qTokenPut400.address
      );

      const [collateralAsset, collateralOwed] = await getCollateralRequirement(
        qTokenPut1400,
        nullQToken,
        optionsAmount
      );

      await expect(
        controller
          .connect(secondAccount)
          .neutralizePosition(collateralTokenId, 0)
      )
        .to.emit(controller, "NeutralizePosition")
        .withArgs(
          await secondAccount.getAddress(),
          qTokenPut1400.address,
          optionsAmount,
          collateralOwed,
          collateralAsset,
          qTokenPut400.address
        );

      expect(
        await qTokenPut1400.balanceOf(await secondAccount.getAddress())
      ).to.equal(ethers.BigNumber.from("0"));

      expect(
        await collateralToken.balanceOf(
          await secondAccount.getAddress(),
          collateralTokenId
        )
      ).to.equal(ethers.BigNumber.from("0"));

      expect(
        await qTokenPut400.balanceOf(await secondAccount.getAddress())
      ).to.equal(optionsAmount);
    });
  });
});
