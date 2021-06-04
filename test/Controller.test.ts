import BN from "bignumber.js";
import { MockContract } from "ethereum-waffle";
import {
  BigNumber,
  BigNumberish,
  BytesLike,
  constants,
  ContractInterface,
  Signer,
  Wallet,
} from "ethers";
import { ethers, upgrades, waffle } from "hardhat";
import { beforeEach, describe } from "mocha";
import Web3 from "web3";
import ORACLE_MANAGER from "../artifacts/contracts/pricing/oracle/ChainlinkOracleManager.sol/ChainlinkOracleManager.json";
import PriceRegistry from "../artifacts/contracts/pricing/PriceRegistry.sol/PriceRegistry.json";
import {
  AssetsRegistry,
  OptionsFactory,
  OracleRegistry,
  QuantCalculator,
} from "../typechain";
import { CollateralToken } from "../typechain/CollateralToken";
import { Controller } from "../typechain/Controller";
import { ControllerV2 } from "../typechain/ControllerV2";
import { ExternalQToken } from "../typechain/ExternalQToken";
import { MockERC20 } from "../typechain/MockERC20";
import { QToken } from "../typechain/QToken";
import { QuantConfig } from "../typechain/QuantConfig";
import { expect, provider } from "./setup";
import {
  ActionArgs,
  deployAssetsRegistry,
  deployCollateralToken,
  deployOptionsFactory,
  deployOracleRegistry,
  deployQuantCalculator,
  deployQuantConfig,
  getSignedTransactionData,
  mockERC20,
} from "./testUtils";

const { deployMockContract } = waffle;
const { AddressZero, Zero } = constants;

type optionParameters = [string, string, string, BigNumber, BigNumber, boolean];

describe("Controller", async () => {
  let controller: Controller;
  let quantConfig: QuantConfig;
  let collateralToken: CollateralToken;
  let deployer: Wallet;
  let secondAccount: Wallet;
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
  let quantCalculator: QuantCalculator;

  const web3 = new Web3();

  const aMonth = 30 * 24 * 3600; // in seconds

  const takeSnapshot = async (): Promise<string> => {
    const id: string = await provider.send("evm_snapshot", [
      new Date().getTime(),
    ]);

    return id;
  };

  const revertToSnapshot = async (id: string) => {
    await provider.send("evm_revert", [id]);
  };

  const getCollateralRequirement = async (
    qTokenToMint: QToken,
    qTokenForCollateral: QToken,
    optionsAmount: BigNumber,
    roundMode: BN.RoundingMode = BN.ROUND_CEIL
  ): Promise<[string, BigNumber]> => {
    let collateralPerOption;

    const qTokenToMintStrikePrice = new BN(
      await (await qTokenToMint.strikePrice()).toString()
    );
    let qTokenForCollateralStrikePrice = new BN(0);
    if (qTokenForCollateral.address !== AddressZero) {
      qTokenForCollateralStrikePrice = new BN(
        (await qTokenForCollateral.strikePrice()).toString()
      );
    }

    const underlying = <MockERC20>(
      new ethers.Contract(
        await qTokenToMint.underlyingAsset(),
        mockERC20Interface,
        provider
      )
    );

    if (await qTokenToMint.isCall()) {
      collateralPerOption = new BN(10).pow(await underlying.decimals());

      if (qTokenForCollateral.address !== AddressZero) {
        collateralPerOption = qTokenToMintStrikePrice.gt(
          qTokenForCollateralStrikePrice
        )
          ? new BN(0)
          : qTokenForCollateralStrikePrice
              .minus(qTokenToMintStrikePrice)
              .times(new BN(10).pow(18))
              .div(qTokenForCollateralStrikePrice);
      }
    } else {
      collateralPerOption = qTokenToMintStrikePrice;

      if (qTokenForCollateral.address !== AddressZero) {
        collateralPerOption = qTokenToMintStrikePrice.gt(
          qTokenForCollateralStrikePrice
        )
          ? qTokenToMintStrikePrice.minus(qTokenForCollateralStrikePrice) // PUT Credit Spread
          : new BN(0); // Put Debit Spread
      }
    }
    const collateralAmount = new BN(optionsAmount.toString())
      .times(collateralPerOption)
      .div(new BN(10).pow(18))
      .integerValue(roundMode);

    return [
      (await qTokenToMint.isCall())
        ? underlying.address
        : await qTokenToMint.strikeAsset(),
      BigNumber.from(collateralAmount.toString()),
    ];
  };

  const testMintingOptions = async (
    qTokenToMintAddress: string,
    optionsAmount: BigNumber,
    qTokenForCollateralAddress: string = AddressZero
  ) => {
    const qTokenToMint = <QToken>(
      new ethers.Contract(qTokenToMintAddress, QTokenInterface, provider)
    );

    const qTokenForCollateral = <QToken>(
      new ethers.Contract(qTokenForCollateralAddress, QTokenInterface, provider)
    );

    const [collateralAddress, collateralAmount] =
      await getCollateralRequirement(
        qTokenToMint,
        qTokenForCollateral,
        optionsAmount
      );

    expect(
      await quantCalculator.getCollateralRequirement(
        qTokenToMint.address,
        qTokenForCollateral.address,

        optionsAmount
      )
    ).to.eql([collateralAddress, collateralAmount]);

    // mint required collateral to the user account
    const collateral = collateralAddress === WETH.address ? WETH : USDC;

    expect(await collateral.balanceOf(secondAccount.address)).to.equal(0);

    await collateral
      .connect(assetsRegistryManager)
      .mint(secondAccount.address, collateralAmount);

    expect(await collateral.balanceOf(secondAccount.address)).to.equal(
      collateralAmount
    );

    // Approve the Controller to use the user's funds
    await collateral
      .connect(secondAccount)
      .approve(controller.address, collateralAmount);

    // Check if it's a spread or a single option
    if (qTokenForCollateralAddress === AddressZero) {
      await expect(
        controller.connect(secondAccount).operate([
          encodeMintOptionArgs({
            to: secondAccount.address,
            qToken: qTokenToMintAddress,
            amount: optionsAmount,
          }),
        ])
      )
        .to.emit(controller, "OptionsPositionMinted")
        .withArgs(
          secondAccount.address,
          secondAccount.address,
          qTokenToMintAddress,
          optionsAmount
        );

      // Check that the user received the CollateralToken
      const collateralTokenId =
        await optionsFactory.qTokenAddressToCollateralTokenId(
          qTokenToMintAddress
        );

      expect(
        await collateralToken.balanceOf(
          secondAccount.address,
          collateralTokenId
        )
      ).to.equal(optionsAmount);
    } else {
      // Mint the qTokenForCollateral to the user address
      expect(
        await qTokenForCollateral.balanceOf(secondAccount.address)
      ).to.equal(ethers.BigNumber.from("0"));

      await qTokenForCollateral
        .connect(optionsMinter)
        .mint(secondAccount.address, optionsAmount);

      expect(
        await qTokenForCollateral.balanceOf(secondAccount.address)
      ).to.equal(optionsAmount);

      await expect(
        controller.connect(secondAccount).operate([
          encodeMintSpreadArgs({
            qTokenToMint: qTokenToMintAddress,
            qTokenForCollateral: qTokenForCollateralAddress,
            amount: optionsAmount,
          }),
        ])
      )
        .to.emit(controller, "SpreadMinted")
        .withArgs(
          secondAccount.address,
          qTokenToMintAddress,
          qTokenForCollateralAddress,
          optionsAmount
        );

      expect(
        await qTokenForCollateral.balanceOf(secondAccount.address)
      ).to.equal(ethers.BigNumber.from("0"));

      const collateralTokenId = await collateralToken.getCollateralTokenId(
        qTokenToMintAddress,
        qTokenForCollateral.address
      );

      expect(
        await collateralToken.balanceOf(
          secondAccount.address,
          collateralTokenId
        )
      ).to.equal(optionsAmount);
    }

    expect(await collateral.balanceOf(secondAccount.address)).to.equal(
      ethers.BigNumber.from("0")
    );

    expect(await collateral.balanceOf(controller.address)).to.equal(
      collateralAmount
    );

    // Check that the user received the QToken
    expect(await qTokenToMint.balanceOf(secondAccount.address)).to.equal(
      optionsAmount
    );
  };

  const testClaimCollateral = async (
    qTokenShort: QToken,
    amountToClaim: BigNumber,
    expiryPrice: BigNumber,
    qTokenLong: QToken = <QToken>(
      new ethers.Contract(AddressZero, QTokenInterface, provider)
    )
  ): Promise<string> => {
    await mockPriceRegistry.mock.hasSettlementPrice.returns(true);

    //Note: Converts to the chainlink 8 decimal format
    await mockPriceRegistry.mock.getSettlementPriceWithDecimals.returns([
      expiryPrice.mul("100"),
      BigNumber.from(8),
    ]);

    const [collateralAddress, collateralRequirement] =
      await getCollateralRequirement(
        qTokenShort,
        qTokenLong,
        amountToClaim,
        BN.ROUND_CEIL
      );

    const collateral = collateralAddress === WETH.address ? WETH : USDC;

    await collateral
      .connect(assetsRegistryManager)
      .mint(secondAccount.address, collateralRequirement);

    let qTokenAsCollateral;
    let collateralRequiredForLong = ethers.BigNumber.from("0");

    if (qTokenLong.address === AddressZero) {
      qTokenAsCollateral = AddressZero;

      await collateral
        .connect(secondAccount)
        .approve(controller.address, collateralRequirement);

      await controller.connect(secondAccount).operate([
        encodeMintOptionArgs({
          to: secondAccount.address,
          qToken: qTokenShort.address,
          amount: amountToClaim,
        }),
      ]);
    } else {
      qTokenAsCollateral = qTokenLong.address;

      collateralRequiredForLong = (
        await getCollateralRequirement(
          qTokenLong,
          nullQToken,
          amountToClaim,
          BN.ROUND_CEIL
        )
      )[1];

      await collateral
        .connect(assetsRegistryManager)
        .mint(secondAccount.address, collateralRequiredForLong);

      await collateral
        .connect(secondAccount)
        .approve(
          controller.address,
          collateralRequirement.add(collateralRequiredForLong)
        );

      await controller.connect(secondAccount).operate([
        encodeMintOptionArgs({
          to: secondAccount.address,
          qToken: qTokenLong.address,
          amount: amountToClaim,
        }),
      ]);

      await controller.connect(secondAccount).operate([
        encodeMintSpreadArgs({
          qTokenToMint: qTokenShort.address,
          qTokenForCollateral: qTokenLong.address,
          amount: amountToClaim,
        }),
      ]);
    }

    const collateralTokenId = await collateralToken.getCollateralTokenId(
      qTokenShort.address,
      qTokenAsCollateral
    );

    // Take a snapshot of the Hardhat Network
    const snapshotId = await takeSnapshot();

    // Increase time to one hour past the expiry
    await provider.send("evm_mine", [futureTimestamp + 3600]);

    const [payoutFromShort, payoutAsset] = await getPayout(
      qTokenShort,
      amountToClaim,
      expiryPrice,
      BN.ROUND_UP
    );

    const payoutFromLong =
      qTokenLong.address !== AddressZero
        ? (await getPayout(qTokenLong, amountToClaim, expiryPrice))[0]
        : ethers.BigNumber.from("0");

    const claimableCollateral = payoutFromLong
      .add(collateralRequirement)
      .sub(payoutFromShort);

    await controller.connect(secondAccount).operate([
      encodeClaimCollateralArgs({
        collateralTokenId,
        amount: amountToClaim,
      }),
    ]);

    const secondAccountCollateralClaimed = await payoutAsset.balanceOf(
      secondAccount.address
    );

    const secondAccountClaimedFundsLostRounding = claimableCollateral.sub(
      secondAccountCollateralClaimed
    );

    //some funds may be lost rounding. check its only 1 wei.
    expect(
      parseInt(secondAccountClaimedFundsLostRounding.toString())
    ).to.be.greaterThanOrEqual(0);

    expect(
      parseInt(secondAccountClaimedFundsLostRounding.toString())
    ).to.be.lessThanOrEqual(1);

    const controllerBalanceAfterClaim = await payoutAsset.balanceOf(
      controller.address
    );
    const intendedControllerBalanceAfterClaim = collateralRequirement
      .add(collateralRequiredForLong)
      .sub(claimableCollateral);

    //should ideally be 0, but can also be extra wei due to rounding
    const controllerExtraFunds = controllerBalanceAfterClaim.sub(
      intendedControllerBalanceAfterClaim
    );

    expect(parseInt(controllerExtraFunds.toString())).to.be.greaterThanOrEqual(
      0
    );
    expect(parseInt(controllerExtraFunds.toString())).to.be.lessThanOrEqual(1); //check the rounding is within 1 wei

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
      parseInt(
        new BN(claimableCollateral.toString())
          .integerValue(BN.ROUND_DOWN)
          .toString()
      ) /
      10 ** (await collateral.decimals())
    } ${payoutAsset.address === USDC.address ? "USDC" : "WETH"}`;

    const qTokenLongStrikePriceString =
      qTokenLong.address !== AddressZero
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
      } so the user is entitled to ~ ${claimableCollateralString}`
    );

    return snapshotId;
  };

  const getPayout = async (
    qToken: QToken,
    amount: BigNumber,
    expiryPrice: BigNumber,
    roundMode: BN.RoundingMode = BN.ROUND_DOWN
  ): Promise<[BigNumber, MockERC20]> => {
    const strikePrice = await qToken.strikePrice();
    const payoutDecimals = await WETH.decimals();
    const optionsDecimals = 18;

    let payoutAmount: BN;
    let payoutToken: MockERC20;

    if (await qToken.isCall()) {
      payoutAmount = expiryPrice.gt(strikePrice)
        ? new BN(expiryPrice.toString())
            .minus(new BN(strikePrice.toString()))
            .times(new BN(amount.toString()))
            .div(new BN(expiryPrice.toString()))
            .times(new BN(10).pow(payoutDecimals))
            .div(new BN(10).pow(optionsDecimals))
        : new BN(0);

      payoutToken = WETH;
    } else {
      payoutAmount = strikePrice.gt(expiryPrice)
        ? new BN(strikePrice.toString())
            .minus(new BN(expiryPrice.toString()))
            .times(new BN(amount.toString()))
            .div(new BN(10).pow(optionsDecimals))
        : new BN(0);

      payoutToken = USDC;
    }

    payoutAmount = payoutAmount.integerValue(roundMode);

    return [BigNumber.from(payoutAmount.toString()), payoutToken];
  };

  type MintOptionArgs = {
    to: string;
    qToken: string;
    amount: BigNumberish;
  };
  type MintSpreadArgs = {
    qTokenToMint: string;
    qTokenForCollateral: string;
    amount: BigNumberish;
  };
  type ExerciseArgs = { qToken: string; amount: BigNumberish };
  type ClaimCollateralArgs = {
    collateralTokenId: BigNumberish;
    amount: BigNumberish;
  };
  type NeutralizeArgs = {
    collateralTokenId: BigNumberish;
    amount: BigNumberish;
  };
  type CallArgs = { callee: string; data: BytesLike };

  const encodeMintOptionArgs = (args: MintOptionArgs): ActionArgs => {
    return {
      actionType: "MINT_OPTION",
      qToken: args.qToken,
      secondaryAddress: AddressZero,
      receiver: args.to,
      amount: args.amount,
      collateralTokenId: Zero.toString(),
      data: "0x",
    };
  };

  const encodeMintSpreadArgs = (args: MintSpreadArgs): ActionArgs => {
    return {
      actionType: "MINT_SPREAD",
      qToken: args.qTokenToMint,
      secondaryAddress: args.qTokenForCollateral,
      receiver: AddressZero,
      amount: args.amount,
      collateralTokenId: Zero.toString(),
      data: "0x",
    };
  };

  const encodeExerciseArgs = (args: ExerciseArgs): ActionArgs => {
    return {
      actionType: "EXERCISE",
      qToken: args.qToken,
      secondaryAddress: AddressZero,
      receiver: AddressZero,
      amount: args.amount,
      collateralTokenId: Zero.toString(),
      data: "0x",
    };
  };

  const encodeClaimCollateralArgs = (args: ClaimCollateralArgs): ActionArgs => {
    return {
      actionType: "CLAIM_COLLATERAL",
      qToken: AddressZero,
      secondaryAddress: AddressZero,
      receiver: AddressZero,
      amount: args.amount,
      collateralTokenId: args.collateralTokenId,
      data: "0x",
    };
  };

  const encodeNeutralizeArgs = (args: NeutralizeArgs): ActionArgs => {
    return {
      actionType: "NEUTRALIZE",
      qToken: AddressZero,
      secondaryAddress: AddressZero,
      receiver: AddressZero,
      amount: args.amount,
      collateralTokenId: args.collateralTokenId,
      data: "0x",
    };
  };

  const encodeCallArgs = (args: CallArgs): ActionArgs => {
    return {
      actionType: "CALL",
      qToken: AddressZero,
      secondaryAddress: AddressZero,
      receiver: args.callee,
      amount: Zero.toString(),
      collateralTokenId: Zero.toString(),
      data: args.data,
    };
  };

  beforeEach(async () => {
    [
      deployer,
      secondAccount,
      assetsRegistryManager,
      collateralMinter,
      optionsMinter,
      collateralCreator,
      oracleManagerAccount,
    ] = await provider.getWallets();

    quantConfig = await deployQuantConfig(deployer, [
      {
        addresses: [await assetsRegistryManager.getAddress()],
        role: "ASSETS_REGISTRY_MANAGER_ROLE",
      },
      {
        addresses: [
          await collateralMinter.getAddress(),
          await assetsRegistryManager.getAddress(),
        ],
        role: "COLLATERAL_MINTER_ROLE",
      },
      {
        addresses: [await optionsMinter.getAddress()],
        role: "OPTIONS_MINTER_ROLE",
      },
      {
        addresses: [await collateralCreator.getAddress()],
        role: "COLLATERAL_CREATOR_ROLE",
      },
      {
        addresses: [await oracleManagerAccount.getAddress()],
        role: "ORACLE_MANAGER_ROLE",
      },
    ]);

    WETH = await mockERC20(assetsRegistryManager, "WETH", "Wrapped Ether");
    USDC = await mockERC20(assetsRegistryManager, "USDC", "USD Coin", 6);
    collateralToken = await deployCollateralToken(deployer, quantConfig);

    assetsRegistry = await deployAssetsRegistry(deployer, quantConfig);

    oracleRegistry = await deployOracleRegistry(deployer, quantConfig);

    mockOracleManager = await deployMockContract(deployer, ORACLE_MANAGER.abi);

    mockOracleManagerTwo = await deployMockContract(
      deployer,
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
      deployer,
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
      .connect(deployer)
      .setProtocolRole("COLLATERAL_CREATOR_ROLE", optionsFactory.address);

    await quantConfig
      .connect(deployer)
      .setProtocolRole("PRICE_SUBMITTER_ROLE", oracleRegistry.address);

    await quantConfig
      .connect(deployer)
      .setProtocolRole("PRICE_SUBMITTER_ROLE_ADMIN", oracleRegistry.address);

    await quantConfig
      .connect(deployer)
      .setRoleAdmin(
        ethers.utils.id("PRICE_SUBMITTER_ROLE"),
        ethers.utils.id("PRICE_SUBMITTER_ROLE_ADMIN")
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
      new ethers.Contract(AddressZero, QTokenInterface, provider)
    );

    const Controller = await ethers.getContractFactory("Controller");

    quantCalculator = await deployQuantCalculator(
      deployer,
      optionsFactory.address
    );

    controller = <Controller>(
      await upgrades.deployProxy(Controller, [
        "Quant Protocol",
        "0.3.4",
        optionsFactory.address,
        quantCalculator.address,
      ])
    );

    await quantConfig
      .connect(deployer)
      .setProtocolRole("OPTIONS_MINTER_ROLE", controller.address);

    await quantConfig
      .connect(deployer)
      .setProtocolRole("OPTIONS_BURNER_ROLE", controller.address);

    await quantConfig
      .connect(deployer)
      .setProtocolRole("COLLATERAL_CREATOR_ROLE", controller.address);

    await quantConfig
      .connect(deployer)
      .setProtocolRole("COLLATERAL_MINTER_ROLE", controller.address);

    await quantConfig
      .connect(deployer)
      .setProtocolRole("COLLATERAL_BURNER_ROLE", controller.address);

    await quantConfig
      .connect(deployer)
      .setProtocolAddress(
        ethers.utils.id("assetsRegistry"),
        assetsRegistry.address
      );

    mockPriceRegistry = await deployMockContract(deployer, PriceRegistry.abi);

    await quantConfig
      .connect(deployer)
      .setProtocolAddress(
        ethers.utils.id("priceRegistry"),
        mockPriceRegistry.address
      );
  });

  it("QTokens that are not created through the OptionsFactory are currently able to be exercised", async () => {
    const optionsAmount = ethers.utils.parseEther("15");

    // Take a snapshot of the Hardhat Network
    const snapshotId = await takeSnapshot();

    // Simulate some user minting real options through the Controller
    // (i.e., QTokens that were created with the OptionsFactory createOption method)
    const mintActions = [
      encodeMintOptionArgs({
        to: deployer.address,
        qToken: qTokenPut1400.address,
        amount: optionsAmount.toString(),
      }),
      encodeMintOptionArgs({
        to: deployer.address,
        qToken: qTokenPut400.address,
        amount: optionsAmount.toString(),
      }),
    ];
    const [, firstCollateralAmount] = await getCollateralRequirement(
      qTokenPut1400,
      nullQToken,
      optionsAmount
    );
    const [, secondCollateralRequirement] = await getCollateralRequirement(
      qTokenPut400,
      nullQToken,
      optionsAmount
    );
    const totalCollateralRequirement = firstCollateralAmount.add(
      secondCollateralRequirement
    );
    const collateral = USDC;
    await collateral
      .connect(assetsRegistryManager)
      .mint(deployer.address, totalCollateralRequirement);
    await collateral
      .connect(deployer)
      .approve(controller.address, totalCollateralRequirement);
    await controller.connect(deployer).operate(mintActions);
    expect(await USDC.balanceOf(controller.address)).to.equal(
      totalCollateralRequirement
    );
    expect(await qTokenPut1400.balanceOf(deployer.address)).to.equal(
      optionsAmount
    );

    expect(await qTokenPut400.balanceOf(deployer.address)).to.equal(
      optionsAmount
    );

    // Now we simulate the first option (PUT 1400) expiring ITM
    await provider.send("evm_mine", [futureTimestamp + 3600]);
    await mockPriceRegistry.mock.hasSettlementPrice.returns(true);
    await mockPriceRegistry.mock.getSettlementPriceWithDecimals.returns([
      ethers.utils.parseUnits("800", 8), // Chainlink ETH/USD oracle has 8 decimals
      BigNumber.from(8),
    ]);

    // A user now comes and deploy a contract that adheres to the IQToken interface,
    // or that simply inherits from the QToken contrac
    const ExternalQToken = await ethers.getContractFactory("ExternalQToken");
    const externalStrikePrice = ethers.utils.parseUnits(
      "2600",
      await USDC.decimals()
    );
    const externalQToken = <ExternalQToken>(
      await ExternalQToken.connect(secondAccount).deploy(
        await qTokenPut1400.quantConfig(),
        await qTokenPut1400.underlyingAsset(),
        await qTokenPut400.strikeAsset(),
        await qTokenPut1400.oracle(),
        externalStrikePrice,
        await qTokenPut1400.expiryTime(),
        await qTokenPut400.isCall()
      )
    );

    // He then mints some of his new, malicious QToken
    await externalQToken
      .connect(secondAccount)
      .permissionlessMint(secondAccount.address, optionsAmount);

    // Which should be enough to drain all the funds in the Controller after exercising
    const payoutAmount = (
      await quantCalculator.getExercisePayout(
        externalQToken.address,
        optionsAmount
      )
    ).payoutAmount;
    expect(await collateral.balanceOf(controller.address)).to.equal(
      payoutAmount
    );

    // With the current Controller implementation, the malicious user should be able
    // to exercise his external QToken, draining all the funds in the Controller
    const exerciseAction = encodeExerciseArgs({
      qToken: externalQToken.address,
      amount: optionsAmount.toString(),
    });
    await controller.connect(secondAccount).operate([exerciseAction]);
    expect(await collateral.balanceOf(controller.address)).to.equal(Zero);
    expect(await collateral.balanceOf(secondAccount.address))
      .to.equal(payoutAmount)
      .to.equal(totalCollateralRequirement);

    revertToSnapshot(snapshotId);
  });

  describe("neutralizePosition", () => {
    it("Should round in favour of the protocol when neutralizing positions", async () => {
      //1400 USD strike -> 1400 * 10^6 = 10^9
      //1 OPTION REQUIRES 1.4 * 10^9
      //10^18 OPTION REQUIRES 1.4 * 10^9
      //1.4 WEI OF USDC NEEDED PER 10^9 options
      //3.5 WEI of USDC NEEDED FOR 2.5 * 10^9
      //4 WEI WHEN ROUNDED UP (MINT) FOR 2.5 * 10^9 OPTIONS
      //3 WEI WHEN ROUNDED DOWN (NEUTRALIZE) FOR 2.5 * 10^9 OPTIONS

      const optionsAmount = ethers.utils.parseUnits("2.5", 9);

      const [, collateralRequirement] = await getCollateralRequirement(
        qTokenPut1400,
        nullQToken,
        optionsAmount,
        BN.ROUND_UP
      );

      expect(collateralRequirement).to.equal(4);

      await USDC.connect(assetsRegistryManager).mint(
        secondAccount.address,
        collateralRequirement
      );

      await USDC.connect(secondAccount).approve(
        controller.address,
        collateralRequirement
      );

      await controller.connect(secondAccount).operate([
        encodeMintOptionArgs({
          to: secondAccount.address,
          qToken: qTokenPut1400.address,
          amount: optionsAmount,
        }),
      ]);

      const collateralTokenId = await collateralToken.getCollateralTokenId(
        qTokenPut1400.address,
        AddressZero
      );

      await controller.connect(secondAccount).operate([
        encodeNeutralizeArgs({
          collateralTokenId,
          amount: optionsAmount,
        }),
      ]);

      expect(await qTokenPut1400.balanceOf(secondAccount.address)).to.equal(
        Zero
      );

      expect(
        await collateralToken.balanceOf(
          secondAccount.address,
          collateralTokenId
        )
      ).to.equal(Zero);

      const [, collateralOwed] = await getCollateralRequirement(
        qTokenPut1400,
        nullQToken,
        optionsAmount,
        BN.ROUND_DOWN
      );

      expect(await USDC.balanceOf(secondAccount.address)).to.equal(
        collateralOwed
      );
      expect(await USDC.balanceOf(controller.address)).to.equal(
        collateralRequirement.sub(collateralOwed)
      );
      expect(collateralOwed).to.equal(3);
    });
  });

  describe("neutralizePosition", () => {
    it("Should revert when users try to neutralize more options than they have", async () => {
      await expect(
        controller.connect(secondAccount).operate([
          encodeNeutralizeArgs({
            collateralTokenId: await collateralToken.getCollateralTokenId(
              qTokenCall3520.address,
              AddressZero
            ),
            amount: ethers.utils.parseEther("4"),
          }),
        ])
      ).to.be.revertedWith("Controller: Tried to neutralize more than balance");
    });

    it("Users should be able to neutralize some of their position", async () => {
      const optionsAmount = ethers.utils.parseEther("5");

      const [, collateralRequirement] = await getCollateralRequirement(
        qTokenPut1400,
        nullQToken,
        optionsAmount,
        BN.ROUND_DOWN
      );

      expect(collateralRequirement).to.equal(
        ethers.utils.parseUnits("7000", 6)
      );

      await USDC.connect(assetsRegistryManager).mint(
        secondAccount.address,
        collateralRequirement
      );

      await USDC.connect(secondAccount).approve(
        controller.address,
        collateralRequirement
      );

      await controller.connect(secondAccount).operate([
        encodeMintOptionArgs({
          to: secondAccount.address,
          qToken: qTokenPut1400.address,
          amount: optionsAmount,
        }),
      ]);

      expect(await USDC.balanceOf(secondAccount.address)).to.equal(Zero);

      const collateralTokenId = await collateralToken.getCollateralTokenId(
        qTokenPut1400.address,
        AddressZero
      );

      expect(await qTokenPut1400.balanceOf(secondAccount.address)).to.equal(
        optionsAmount
      );

      expect(
        await collateralToken.balanceOf(
          secondAccount.address,
          collateralTokenId
        )
      ).to.equal(optionsAmount);

      const amountToNeutralize = ethers.utils.parseEther("3");

      await controller.connect(secondAccount).operate([
        encodeNeutralizeArgs({
          collateralTokenId,
          amount: amountToNeutralize,
        }),
      ]);

      const remainingAmount = optionsAmount.sub(amountToNeutralize);
      expect(remainingAmount).to.equal(ethers.utils.parseEther("2"));

      expect(await qTokenPut1400.balanceOf(secondAccount.address)).to.equal(
        remainingAmount
      );

      expect(
        await collateralToken.balanceOf(
          secondAccount.address,
          collateralTokenId
        )
      ).to.equal(remainingAmount);

      expect(await USDC.balanceOf(secondAccount.address)).to.equal(
        ethers.utils.parseUnits("4200", 6)
      );

      expect(await USDC.balanceOf(controller.address)).to.equal(
        ethers.utils.parseUnits("2800", 6)
      );
    });

    it("Users should be able to neutralize all of their position, and get the long QToken back from a spread", async () => {
      const optionsAmount = ethers.utils.parseEther("5");

      const [, spreadCollateralRequirement] = await getCollateralRequirement(
        qTokenPut1400,
        qTokenPut400,
        optionsAmount
      );

      expect(spreadCollateralRequirement).to.equal(
        ethers.utils.parseUnits("5000", 6)
      );

      const [, longCollateralRequirement] = await getCollateralRequirement(
        qTokenPut400,
        nullQToken,
        optionsAmount
      );

      expect(longCollateralRequirement).to.equal(
        ethers.utils.parseUnits("2000", 6)
      );

      await USDC.connect(assetsRegistryManager).mint(
        secondAccount.address,
        spreadCollateralRequirement.add(longCollateralRequirement)
      );

      await USDC.connect(secondAccount).approve(
        controller.address,
        spreadCollateralRequirement.add(longCollateralRequirement)
      );

      await controller.connect(secondAccount).operate([
        encodeMintOptionArgs({
          to: secondAccount.address,
          qToken: qTokenPut400.address,
          amount: optionsAmount,
        }),
      ]);

      const collateralTokenForLong = await collateralToken.getCollateralTokenId(
        qTokenPut400.address,
        AddressZero
      );

      expect(
        await collateralToken.balanceOf(
          secondAccount.address,
          collateralTokenForLong
        )
      ).to.equal(optionsAmount);

      expect(await qTokenPut400.balanceOf(secondAccount.address)).to.equal(
        optionsAmount
      );

      expect(await USDC.balanceOf(secondAccount.address)).to.equal(
        spreadCollateralRequirement
      );

      expect(await USDC.balanceOf(controller.address)).to.equal(
        longCollateralRequirement
      );

      await controller.connect(secondAccount).operate([
        encodeMintSpreadArgs({
          qTokenToMint: qTokenPut1400.address,
          qTokenForCollateral: qTokenPut400.address,
          amount: optionsAmount,
        }),
      ]);

      const collateralTokenForSpread =
        await collateralToken.getCollateralTokenId(
          qTokenPut1400.address,
          qTokenPut400.address
        );

      expect(
        await collateralToken.balanceOf(
          secondAccount.address,
          collateralTokenForLong
        )
      ).to.equal(optionsAmount);

      expect(
        await collateralToken.balanceOf(
          secondAccount.address,
          collateralTokenForSpread
        )
      ).to.equal(optionsAmount);

      expect(await qTokenPut400.balanceOf(secondAccount.address)).to.equal(
        Zero
      );

      expect(await USDC.balanceOf(secondAccount.address)).to.equal(Zero);

      expect(await USDC.balanceOf(controller.address)).to.equal(
        longCollateralRequirement.add(spreadCollateralRequirement)
      );

      const [collateralAsset, collateralOwed] = await getCollateralRequirement(
        qTokenPut1400,
        qTokenPut400,
        optionsAmount,
        BN.ROUND_DOWN
      );

      expect(collateralOwed).to.equal(spreadCollateralRequirement);

      await expect(
        controller.connect(secondAccount).operate([
          encodeNeutralizeArgs({
            collateralTokenId: collateralTokenForSpread,
            amount: Zero,
          }),
        ])
      )
        .to.emit(controller, "NeutralizePosition")
        .withArgs(
          secondAccount.address,
          qTokenPut1400.address,
          optionsAmount,
          collateralOwed,
          collateralAsset,
          qTokenPut400.address
        );

      expect(await qTokenPut1400.balanceOf(secondAccount.address)).to.equal(
        Zero
      );

      expect(await qTokenPut400.balanceOf(secondAccount.address)).to.equal(
        optionsAmount
      );

      expect(
        await collateralToken.balanceOf(
          secondAccount.address,
          collateralTokenForSpread
        )
      ).to.equal(Zero);

      expect(
        await collateralToken.balanceOf(
          secondAccount.address,
          collateralTokenForLong
        )
      ).to.equal(optionsAmount);

      expect(await USDC.balanceOf(secondAccount.address)).to.equal(
        collateralOwed
      );

      expect(await USDC.balanceOf(controller.address)).to.equal(
        longCollateralRequirement
      );
    });

    //TODO: COPIED THIS TEST CASE FROM ABOVE... NEED TO WRITE PROPERLY...
    it("Users should be able to neutralize some of their position, and get the long QToken back from a spread when the collateral requirement is 0", async () => {
      const optionsAmount = ethers.utils.parseEther("5");
      const amountToNeutralize = ethers.utils.parseEther("3");

      const [, spreadCollateralRequirement] = await getCollateralRequirement(
        qTokenPut400,
        qTokenPut1400,
        optionsAmount
      );

      expect(spreadCollateralRequirement).to.equal(
        ethers.utils.parseUnits("0", 6)
      );

      const [, longCollateralRequirement] = await getCollateralRequirement(
        qTokenPut1400,
        nullQToken,
        optionsAmount
      );

      expect(longCollateralRequirement).to.equal(
        ethers.utils.parseUnits("7000", 6)
      );

      await USDC.connect(assetsRegistryManager).mint(
        secondAccount.address,
        spreadCollateralRequirement.add(longCollateralRequirement)
      );

      await USDC.connect(secondAccount).approve(
        controller.address,
        spreadCollateralRequirement.add(longCollateralRequirement)
      );

      await controller.connect(secondAccount).operate([
        encodeMintOptionArgs({
          to: secondAccount.address,
          qToken: qTokenPut1400.address,
          amount: optionsAmount,
        }),
      ]);

      const collateralTokenForLong = await collateralToken.getCollateralTokenId(
        qTokenPut1400.address,
        AddressZero
      );

      expect(
        await collateralToken.balanceOf(
          secondAccount.address,
          collateralTokenForLong
        )
      ).to.equal(optionsAmount);

      expect(await qTokenPut1400.balanceOf(secondAccount.address)).to.equal(
        optionsAmount
      );

      expect(await USDC.balanceOf(secondAccount.address)).to.equal(
        spreadCollateralRequirement
      );

      expect(await USDC.balanceOf(controller.address)).to.equal(
        longCollateralRequirement
      );

      await controller.connect(secondAccount).operate([
        encodeMintSpreadArgs({
          qTokenToMint: qTokenPut400.address,
          qTokenForCollateral: qTokenPut1400.address,
          amount: optionsAmount,
        }),
      ]);

      const collateralTokenForSpread =
        await collateralToken.getCollateralTokenId(
          qTokenPut400.address,
          qTokenPut1400.address
        );

      expect(
        await collateralToken.balanceOf(
          secondAccount.address,
          collateralTokenForLong
        )
      ).to.equal(optionsAmount);

      expect(
        await collateralToken.balanceOf(
          secondAccount.address,
          collateralTokenForSpread
        )
      ).to.equal(optionsAmount);

      expect(await qTokenPut1400.balanceOf(secondAccount.address)).to.equal(
        Zero
      );

      expect(await USDC.balanceOf(secondAccount.address)).to.equal(Zero);

      expect(await USDC.balanceOf(controller.address)).to.equal(
        longCollateralRequirement.add(spreadCollateralRequirement)
      );

      const [collateralAsset, collateralOwed] = await getCollateralRequirement(
        qTokenPut400,
        qTokenPut1400,
        amountToNeutralize,
        BN.ROUND_DOWN
      );

      expect(collateralOwed).to.equal(Zero);

      await expect(
        controller.connect(secondAccount).operate([
          encodeNeutralizeArgs({
            collateralTokenId: collateralTokenForSpread,
            amount: amountToNeutralize,
          }),
        ])
      )
        .to.emit(controller, "NeutralizePosition")
        .withArgs(
          secondAccount.address,
          qTokenPut400.address,
          amountToNeutralize,
          collateralOwed,
          collateralAsset,
          qTokenPut1400.address
        );

      expect(await qTokenPut400.balanceOf(secondAccount.address)).to.equal(
        optionsAmount.sub(amountToNeutralize)
      );

      expect(await qTokenPut1400.balanceOf(secondAccount.address)).to.equal(
        amountToNeutralize
      );

      expect(
        await collateralToken.balanceOf(
          secondAccount.address,
          collateralTokenForSpread
        )
      ).to.equal(optionsAmount.sub(amountToNeutralize));

      expect(
        await collateralToken.balanceOf(
          secondAccount.address,
          collateralTokenForLong
        )
      ).to.equal(optionsAmount);

      expect(await USDC.balanceOf(secondAccount.address)).to.equal(
        collateralOwed
      );

      expect(collateralOwed).to.equal(Zero);

      expect(await USDC.balanceOf(controller.address)).to.equal(
        longCollateralRequirement
      );
    });
  });

  describe("mintOptionsPosition", () => {
    it("Should revert when trying to mint an option which has an oracle which is deactivated", async () => {
      await oracleRegistry
        .connect(oracleManagerAccount)
        .deactivateOracle(mockOracleManager.address);

      await expect(
        controller.connect(secondAccount).operate([
          encodeMintOptionArgs({
            to: secondAccount.address,
            qToken: qTokenCall2000.address,
            amount: ethers.BigNumber.from("10"),
          }),
        ])
      ).to.be.revertedWith(
        "Controller: Can't mint an options position as the oracle is inactive"
      );
    });

    it("Should revert when trying to mint a non-existent option", async () => {
      await expect(
        controller.connect(secondAccount).operate([
          encodeMintOptionArgs({
            to: secondAccount.address,
            qToken: AddressZero,
            amount: ethers.BigNumber.from("10"),
          }),
        ])
      ).to.be.revertedWith(
        "Controller: Option needs to be created by the factory first"
      );
    });

    it("Should revert when trying to mint an already expired option", async () => {
      // Take a snapshot of the Hardhat Network
      const snapshotId = await takeSnapshot();

      // Increase time to one hour past the expiry
      await provider.send("evm_mine", [futureTimestamp + 3600]);

      await expect(
        controller.connect(secondAccount).operate([
          encodeMintOptionArgs({
            to: secondAccount.address,
            qToken: qTokenPut1400.address,
            amount: ethers.BigNumber.from("10"),
          }),
        ])
      ).to.be.revertedWith("Controller: Cannot mint expired options");

      revertToSnapshot(snapshotId);
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
        controller.connect(secondAccount).operate([
          encodeMintSpreadArgs({
            qTokenToMint: qTokenOracleOne,
            qTokenForCollateral: qTokenOracleTwo,
            amount: ethers.utils.parseEther("1"),
          }),
        ])
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
      const qTokenPutDifferentExpiry =
        await optionsFactory.getTargetQTokenAddress(...qTokenParams);

      await optionsFactory.connect(secondAccount).createOption(...qTokenParams);

      await expect(
        controller.connect(secondAccount).operate([
          encodeMintSpreadArgs({
            qTokenToMint: qTokenPutDifferentExpiry,
            qTokenForCollateral: qTokenPut1400.address,
            amount: ethers.utils.parseEther("1"),
          }),
        ])
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
      const qTokenCallDifferentUnderlying =
        await optionsFactory.getTargetQTokenAddress(...qTokenParams);

      await optionsFactory.createOption(...qTokenParams);

      await expect(
        controller.connect(secondAccount).operate([
          encodeMintSpreadArgs({
            qTokenToMint: qTokenCallDifferentUnderlying,
            qTokenForCollateral: qTokenCall3520.address,
            amount: ethers.utils.parseEther("1"),
          }),
        ])
      ).to.be.revertedWith(
        "Controller: Can't create spreads from options with different underlying assets"
      );
    });

    it("Should revert when trying to create spreads with the same short and long qTokens", async () => {
      await expect(
        controller.connect(secondAccount).operate([
          encodeMintSpreadArgs({
            qTokenToMint: qTokenCall2000.address,
            qTokenForCollateral: qTokenCall2000.address,
            amount: ethers.utils.parseEther("1"),
          }),
        ])
      ).to.be.revertedWith(
        "Controller: Can only create a spread with different tokens"
      );
    });

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
        controller.connect(secondAccount).operate([
          encodeExerciseArgs({
            qToken: qTokenPut1400.address,
            amount: ethers.utils.parseEther("1"),
          }),
        ])
      ).to.be.revertedWith(
        "Controller: Can not exercise options before their expiry"
      );
    });

    it("Should revert when trying to exercise unsettled options", async () => {
      // Take a snapshot of the Hardhat Network
      const snapshotId = await takeSnapshot();

      // Increase time to one hour past the expiry
      await provider.send("evm_mine", [futureTimestamp + 3600]);

      await mockPriceRegistry.mock.hasSettlementPrice.returns(false);

      await expect(
        controller.connect(secondAccount).operate([
          encodeExerciseArgs({
            qToken: qTokenPut1400.address,
            amount: ethers.utils.parseEther("1"),
          }),
        ])
      ).to.be.revertedWith("Controller: Cannot exercise unsettled options");

      await revertToSnapshot(snapshotId);
    });

    it("Users should be able to exercise PUT options", async () => {
      // Take a snapshot of the Hardhat Network
      const snapshotId = await takeSnapshot();

      // Increase time to one hour past the expiry
      await provider.send("evm_mine", [futureTimestamp + 3600]);

      await mockPriceRegistry.mock.hasSettlementPrice.returns(true);

      //Note: Converts to the chainlink 8 decimal format
      await mockPriceRegistry.mock.getSettlementPriceWithDecimals.returns([
        ethers.utils.parseUnits("1200", 8),
        BigNumber.from(8),
      ]);

      // Mint options to the user
      const optionsAmount = ethers.utils.parseEther("1");
      const qTokenToExercise = qTokenPut1400;
      await qTokenToExercise
        .connect(optionsMinter)
        .mint(secondAccount.address, optionsAmount);

      expect(await USDC.balanceOf(secondAccount.address)).to.equal(
        ethers.BigNumber.from("0")
      );

      expect(await qTokenToExercise.balanceOf(secondAccount.address)).to.equal(
        optionsAmount
      );

      const payoutAmount = (
        await quantCalculator.getExercisePayout(
          qTokenToExercise.address,
          optionsAmount
        )
      ).payoutAmount;

      // Mint USDC to the Controller so it can pay the user
      await USDC.connect(deployer).mint(controller.address, payoutAmount);
      expect(await USDC.balanceOf(controller.address)).to.equal(payoutAmount);

      await expect(
        controller.connect(secondAccount).operate([
          encodeExerciseArgs({
            qToken: qTokenToExercise.address,
            amount: optionsAmount,
          }),
        ])
      )
        .to.emit(controller, "OptionsExercised")
        .withArgs(
          secondAccount.address,
          qTokenToExercise.address,
          optionsAmount,
          payoutAmount,
          USDC.address
        );

      expect(await USDC.balanceOf(secondAccount.address)).to.equal(
        payoutAmount
      );
      expect(await USDC.balanceOf(controller.address)).to.equal(
        ethers.BigNumber.from("0")
      );
      expect(await qTokenToExercise.balanceOf(secondAccount.address)).to.equal(
        ethers.BigNumber.from("0")
      );

      revertToSnapshot(snapshotId);
    });

    it("Users should be able to exercise CALL options", async () => {
      // Take a snapshot of the Hardhat Network
      const snapshotId = await takeSnapshot();

      // Increase time to one hour past the expiry
      await provider.send("evm_mine", [futureTimestamp + 3600]);

      await mockPriceRegistry.mock.hasSettlementPrice.returns(true);

      //Note: Converts to the chainlink 8 decimal format
      await mockPriceRegistry.mock.getSettlementPriceWithDecimals.returns([
        ethers.utils.parseUnits("2500", 8),
        BigNumber.from(8),
      ]);

      // Mint options to the user
      const optionsAmount = ethers.utils.parseEther("2");
      const qTokenToExercise = qTokenCall2000;
      await qTokenToExercise
        .connect(optionsMinter)
        .mint(secondAccount.address, optionsAmount);

      expect(await WETH.balanceOf(secondAccount.address)).to.equal(
        ethers.BigNumber.from("0")
      );

      expect(await qTokenToExercise.balanceOf(secondAccount.address)).to.equal(
        optionsAmount
      );

      const payoutAmount = (
        await quantCalculator.getExercisePayout(
          qTokenToExercise.address,
          optionsAmount
        )
      ).payoutAmount;

      // Mint WETH to the Controller so it can pay the user
      await WETH.connect(assetsRegistryManager).mint(
        controller.address,
        payoutAmount
      );
      expect(await WETH.balanceOf(controller.address)).to.equal(payoutAmount);

      await expect(
        controller.connect(secondAccount).operate([
          encodeExerciseArgs({
            qToken: qTokenToExercise.address,
            amount: Zero,
          }),
        ])
      )
        .to.emit(controller, "OptionsExercised")
        .withArgs(
          secondAccount.address,
          qTokenToExercise.address,
          optionsAmount,
          payoutAmount,
          WETH.address
        );

      expect(await WETH.balanceOf(secondAccount.address)).to.equal(
        payoutAmount
      );
      expect(await WETH.balanceOf(controller.address)).to.equal(
        ethers.BigNumber.from("0")
      );
      expect(await qTokenToExercise.balanceOf(secondAccount.address)).to.equal(
        ethers.BigNumber.from("0")
      );

      revertToSnapshot(snapshotId);
    });

    it("Should revert when a user tries to exercise an amount of options that exceeds his balance", async () => {
      // Take a snapshot of the Hardhat Network
      const snapshotId = await takeSnapshot();

      // Increase time to one hour past the expiry
      await provider.send("evm_mine", [futureTimestamp + 3600]);

      await mockPriceRegistry.mock.hasSettlementPrice.returns(true);

      //Note: Converts to the chainlink 8 decimal format
      await mockPriceRegistry.mock.getSettlementPriceWithDecimals.returns([
        ethers.utils.parseUnits("200", 8),
        8,
      ]);

      await expect(
        controller.connect(secondAccount).operate([
          encodeExerciseArgs({
            qToken: qTokenPut1400.address,
            amount: ethers.utils.parseEther("1"),
          }),
        ])
      ).to.be.revertedWith("ERC20: burn amount exceeds balance");

      revertToSnapshot(snapshotId);
    });

    it("Burns the QTokens but don't transfer anything when options expire OTM", async () => {
      // Take a snapshot of the Hardhat Network
      const snapshotId = await takeSnapshot();

      // Increase time to one hour past the expiry
      await provider.send("evm_mine", [futureTimestamp + 3600]);

      await mockPriceRegistry.mock.hasSettlementPrice.returns(true);

      //Note: Converts to the chainlink 8 decimal format
      await mockPriceRegistry.mock.getSettlementPriceWithDecimals.returns([
        ethers.utils.parseUnits("1800", 8),
        8,
      ]);

      // Mint options to the user
      const optionsAmount = ethers.utils.parseEther("3");
      const qTokenToExercise = qTokenCall2000;
      await qTokenToExercise
        .connect(optionsMinter)
        .mint(secondAccount.address, optionsAmount);

      await controller.connect(secondAccount).operate([
        encodeExerciseArgs({
          qToken: qTokenToExercise.address,
          amount: optionsAmount,
        }),
      ]);

      expect(await qTokenToExercise.balanceOf(secondAccount.address)).to.equal(
        ethers.BigNumber.from("0")
      );

      expect(await WETH.balanceOf(secondAccount.address)).to.equal(
        ethers.BigNumber.from("0")
      );

      revertToSnapshot(snapshotId);
    });
  });

  describe("claimCollateral", () => {
    it("Should revert when trying to claim collateral from an invalid CollateralToken", async () => {
      await expect(
        controller.connect(secondAccount).operate([
          encodeClaimCollateralArgs({
            collateralTokenId: ethers.BigNumber.from("123"),
            amount: ethers.utils.parseEther("1"),
          }),
        ])
      ).to.be.revertedWith("Can not claim collateral from non-existing option");
    });

    it("Should revert when trying to claim collateral from options before their expiry", async () => {
      await expect(
        controller.connect(secondAccount).operate([
          encodeClaimCollateralArgs({
            collateralTokenId: await collateralToken.getCollateralTokenId(
              qTokenPut400.address,
              AddressZero
            ),
            amount: ethers.utils.parseEther("1"),
          }),
        ])
      ).to.be.revertedWith(
        "Can not claim collateral from options before their expiry"
      );
    });

    it("Should revert when trying to claim collateral from options before their expiry price is settled", async () => {
      // Take a snapshot of the Hardhat Network
      const snapshotId = await takeSnapshot();

      // Increase time to one hour past the expiry
      await provider.send("evm_mine", [futureTimestamp + 3600]);

      await mockPriceRegistry.mock.hasSettlementPrice.returns(false);

      await expect(
        controller.connect(secondAccount).operate([
          encodeClaimCollateralArgs({
            collateralTokenId: await collateralToken.getCollateralTokenId(
              qTokenPut400.address,
              AddressZero
            ),
            amount: ethers.utils.parseEther("1"),
          }),
        ])
      ).to.be.revertedWith("Can not claim collateral before option is settled");

      revertToSnapshot(snapshotId);
    });

    it("Users should be able to claim collateral from PUT options that expired ITM", async () => {
      const expiryPrice = ethers.utils.parseUnits("300", await USDC.decimals());

      const snapshotId = await testClaimCollateral(
        qTokenPut400,
        ethers.utils.parseEther("1"),
        expiryPrice
      );

      revertToSnapshot(snapshotId);
    });

    it("Users should be able to claim collateral from PUT options that expired OTM", async () => {
      const expiryPrice = ethers.utils.parseUnits("500", await USDC.decimals());

      const snapshotId = await testClaimCollateral(
        qTokenPut400,
        ethers.utils.parseEther("1"),
        expiryPrice
      );

      revertToSnapshot(snapshotId);
    });

    it("Users should be able to claim collateral from PUT options that expired ATM", async () => {
      const expiryPrice = ethers.utils.parseUnits("400", await USDC.decimals());

      const snapshotId = await testClaimCollateral(
        qTokenPut400,
        ethers.utils.parseEther("1"),
        expiryPrice
      );

      revertToSnapshot(snapshotId);
    });

    it("Users should be able to claim collateral from CALL options that expired ITM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "2500",
        await USDC.decimals()
      );

      const snapshotId = await testClaimCollateral(
        qTokenCall2000,
        ethers.utils.parseEther("1"),
        expiryPrice
      );

      revertToSnapshot(snapshotId);
    });

    it("Users should be able to claim collateral from CALL options that expired OTM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "1800",
        await USDC.decimals()
      );

      const snapshotId = await testClaimCollateral(
        qTokenCall2000,
        ethers.utils.parseEther("1"),
        expiryPrice
      );

      revertToSnapshot(snapshotId);
    });

    it("Users should be able to claim collateral from CALL options that expired ATM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "2000",
        await USDC.decimals()
      );

      const snapshotId = await testClaimCollateral(
        qTokenCall2000,
        ethers.utils.parseEther("1"),
        expiryPrice
      );

      revertToSnapshot(snapshotId);
    });

    it("Users should be able to claim collateral from PUT Credit Spreads that expired ITM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "1100",
        await USDC.decimals()
      );

      const snapshotId = await testClaimCollateral(
        qTokenPut1400,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenPut400
      );

      revertToSnapshot(snapshotId);
    });

    it("PUT Credit Spreads that expired ITM and below the coverage of the spread CollateralToken", async () => {
      const expiryPrice = ethers.utils.parseUnits("300", await USDC.decimals());

      const snapshotId = await testClaimCollateral(
        qTokenPut1400,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenPut400
      );

      expect(await USDC.balanceOf(secondAccount.address)).to.equal(
        ethers.BigNumber.from("0")
      );

      revertToSnapshot(snapshotId);
    });

    it("Users should be able to claim collateral from PUT Credit Spreads that expired OTM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "1800",
        await USDC.decimals()
      );

      const snapshotId = await testClaimCollateral(
        qTokenPut1400,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenPut400
      );

      revertToSnapshot(snapshotId);
    });

    it("Users should be able to claim collateral from PUT Credit Spreads that expired ATM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "1400",
        await USDC.decimals()
      );

      const snapshotId = await testClaimCollateral(
        qTokenPut1400,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenPut400
      );

      revertToSnapshot(snapshotId);
    });

    it("Users should be able to claim collateral from PUT Debit Spreads that expired ITM", async () => {
      const expiryPrice = ethers.utils.parseUnits("200", await USDC.decimals());

      const snapshotId = await testClaimCollateral(
        qTokenPut400,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenPut1400
      );

      revertToSnapshot(snapshotId);
    });

    it("Users should be able to claim collateral from PUT Debit Spreads that expired OTM", async () => {
      const expiryPrice = ethers.utils.parseUnits("600", await USDC.decimals());

      const snapshotId = await testClaimCollateral(
        qTokenPut400,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenPut1400
      );

      revertToSnapshot(snapshotId);
    });

    it("Users should be able to claim collateral from PUT Debit Spreads that expired ATM", async () => {
      const expiryPrice = ethers.utils.parseUnits("400", await USDC.decimals());

      const snapshotId = await testClaimCollateral(
        qTokenPut400,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenPut1400
      );

      revertToSnapshot(snapshotId);
    });

    it("Users should be able to claim collateral from CALL Credit Spreads that expired ITM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "3200",
        await USDC.decimals()
      );

      const snapshotId = await testClaimCollateral(
        qTokenCall2880,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenCall3520
      );

      revertToSnapshot(snapshotId);
    });

    it("Users should be able to claim collateral from CALL Credit Spreads that expired OTM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "2600",
        await USDC.decimals()
      );

      const snapshotId = await testClaimCollateral(
        qTokenCall2880,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenCall3520
      );

      revertToSnapshot(snapshotId);
    });

    it("Users should be able to claim collateral from CALL Credit Spreads that expired ATM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "2880",
        await USDC.decimals()
      );

      const snapshotId = await testClaimCollateral(
        qTokenCall2880,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenCall3520
      );

      revertToSnapshot(snapshotId);
    });

    it("CALL Credit Spreads that expired ITM, at the strike price of the long option", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "3520",
        await USDC.decimals()
      );

      const snapshotId = await testClaimCollateral(
        qTokenCall2880,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenCall3520
      );

      expect(await WETH.balanceOf(secondAccount.address)).to.equal(
        ethers.BigNumber.from("0")
      );

      revertToSnapshot(snapshotId);
    });

    it("Users should be able to claim collateral from CALL Debit Spreads that expired ITM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "4000",
        await USDC.decimals()
      );

      const snapshotId = await testClaimCollateral(
        qTokenCall3520,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenCall2880
      );

      revertToSnapshot(snapshotId);
    });

    it("Users should be able to claim collateral from CALL Debit Spreads that expired OTM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "3000",
        await USDC.decimals()
      );

      const snapshotId = await testClaimCollateral(
        qTokenCall3520,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenCall2880
      );

      revertToSnapshot(snapshotId);
    });

    it("Users should be able to claim collateral from CALL Debit Spreads that expired ATM", async () => {
      const expiryPrice = ethers.utils.parseUnits(
        "3520",
        await USDC.decimals()
      );

      const snapshotId = await testClaimCollateral(
        qTokenCall3520,
        ethers.utils.parseEther("1"),
        expiryPrice,
        qTokenCall2880
      );

      revertToSnapshot(snapshotId);
    });
  });

  describe("Meta transactions", () => {
    it("Users should be able to mint options through meta transactions", async () => {
      const amount = ethers.utils.parseEther("1");

      const actions = [
        encodeMintOptionArgs({
          to: secondAccount.address,
          qToken: qTokenCall2000.address,
          amount: amount.toString(),
        }),
      ];

      const txData = await getSignedTransactionData(
        parseInt((await controller.getNonce(deployer.address)).toString()),
        deployer,
        actions,
        controller.address
      );

      const [collateralAddress, collateralAmount] =
        await getCollateralRequirement(qTokenCall2000, nullQToken, amount);
      // mint required collateral to the user account
      const collateral = collateralAddress === WETH.address ? WETH : USDC;
      await collateral
        .connect(assetsRegistryManager)
        .mint(await deployer.address, collateralAmount);
      // Approve the Controller to use the user's funds
      await collateral
        .connect(deployer)
        .approve(controller.address, collateralAmount);

      expect(await qTokenCall2000.balanceOf(secondAccount.address)).to.equal(
        Zero
      );
      expect(await collateral.balanceOf(deployer.address)).to.equal(
        collateralAmount
      );

      await controller
        .connect(secondAccount)
        .executeMetaTransaction(
          deployer.address,
          actions,
          txData.r,
          txData.s,
          txData.v
        );

      expect(await qTokenCall2000.balanceOf(secondAccount.address)).to.equal(
        amount
      );
      expect(await collateral.balanceOf(deployer.address)).to.equal(Zero);
    });
    it("Users should be able to create spreads through meta transactions", async () => {
      const amount = ethers.utils.parseEther("1");

      const actions = [
        encodeMintSpreadArgs({
          qTokenToMint: qTokenCall2880.address,
          qTokenForCollateral: qTokenCall3520.address,
          amount: amount.toString(),
        }),
      ];

      const txData = await getSignedTransactionData(
        parseInt((await controller.getNonce(deployer.address)).toString()),
        deployer,
        actions,
        controller.address
      );

      const [collateralAddress, collateralAmount] =
        await getCollateralRequirement(qTokenCall2880, qTokenCall3520, amount);

      const collateral = collateralAddress === WETH.address ? WETH : USDC;

      await collateral
        .connect(assetsRegistryManager)
        .mint(deployer.address, collateralAmount);

      await collateral
        .connect(deployer)
        .approve(controller.address, collateralAmount);

      await qTokenCall3520
        .connect(optionsMinter)
        .mint(deployer.address, amount);

      await controller
        .connect(secondAccount)
        .executeMetaTransaction(
          deployer.address,
          actions,
          txData.r,
          txData.s,
          txData.v
        );

      expect(await qTokenCall3520.balanceOf(deployer.address)).to.equal(
        ethers.BigNumber.from("0")
      );

      const collateralTokenId = await collateralToken.getCollateralTokenId(
        qTokenCall2880.address,
        qTokenCall3520.address
      );

      expect(
        await collateralToken.balanceOf(deployer.address, collateralTokenId)
      ).to.equal(amount);

      expect(await collateral.balanceOf(deployer.address)).to.equal(
        ethers.BigNumber.from("0")
      );

      expect(await collateral.balanceOf(controller.address)).to.equal(
        collateralAmount
      );
    });

    it("Users should be able to exercise options through meta transactions", async () => {
      //Take a snapshot of the Hardhat Network
      const snapshotId = await takeSnapshot();

      // Increase time to one hour past the expiry
      await provider.send("evm_mine", [futureTimestamp + 3600]);

      await mockPriceRegistry.mock.hasSettlementPrice.returns(true);

      //Note: Converts to the chainlink 8 decimal format
      await mockPriceRegistry.mock.getSettlementPriceWithDecimals.returns([
        ethers.utils.parseUnits("1200", 8),
        BigNumber.from(8),
      ]);

      // Mint options to the user
      const optionsAmount = ethers.utils.parseEther("1");
      const qTokenToExercise = qTokenPut1400;
      await qTokenToExercise
        .connect(optionsMinter)
        .mint(deployer.address, optionsAmount);

      const payoutAmount = (
        await quantCalculator.getExercisePayout(
          qTokenToExercise.address,
          optionsAmount
        )
      ).payoutAmount;

      // Mint USDC to the Controller so it can pay the user
      await USDC.connect(deployer).mint(controller.address, payoutAmount);
      expect(await USDC.balanceOf(controller.address)).to.equal(payoutAmount);

      const actions = [
        encodeExerciseArgs({
          qToken: qTokenToExercise.address,
          amount: optionsAmount.toString(),
        }),
      ];

      const txData = await getSignedTransactionData(
        parseInt((await controller.getNonce(deployer.address)).toString()),
        deployer,
        actions,
        controller.address
      );

      await controller
        .connect(secondAccount)
        .executeMetaTransaction(
          deployer.address,
          actions,
          txData.r,
          txData.s,
          txData.v
        );

      expect(await USDC.balanceOf(deployer.address)).to.equal(payoutAmount);
      expect(await USDC.balanceOf(controller.address)).to.equal(
        ethers.BigNumber.from("0")
      );
      expect(await qTokenToExercise.balanceOf(deployer.address)).to.equal(
        ethers.BigNumber.from("0")
      );

      await revertToSnapshot(snapshotId);
    });

    it("Users should be able to claim collateral through meta transactions", async () => {
      const expiryPrice = ethers.utils.parseUnits("300", await USDC.decimals());

      await mockPriceRegistry.mock.hasSettlementPrice.returns(true);

      //Note: Converts to the chainlink 8 decimal format
      await mockPriceRegistry.mock.getSettlementPriceWithDecimals.returns([
        expiryPrice.mul("100"),
        BigNumber.from(8),
      ]);

      const optionsAmount = ethers.utils.parseEther("1");

      const [collateralAddress, collateralRequirement] =
        await getCollateralRequirement(
          qTokenPut400,
          nullQToken,
          optionsAmount,
          BN.ROUND_CEIL
        );

      const collateral = collateralAddress === WETH.address ? WETH : USDC;

      await collateral
        .connect(assetsRegistryManager)
        .mint(deployer.address, collateralRequirement);

      await collateral
        .connect(deployer)
        .approve(controller.address, collateralRequirement);

      await controller.connect(deployer).operate([
        encodeMintOptionArgs({
          to: deployer.address,
          qToken: qTokenPut400.address,
          amount: optionsAmount,
        }),
      ]);

      const collateralTokenId = await collateralToken.getCollateralTokenId(
        qTokenPut400.address,
        AddressZero
      );

      // Take a snapshot of the Hardhat Network
      const snapshotId = await takeSnapshot();

      // Increase time to one hour past the expiry
      await provider.send("evm_mine", [futureTimestamp + 3600]);

      const [payoutFromShort, payoutAsset] = await getPayout(
        qTokenPut400,
        optionsAmount,
        expiryPrice,
        BN.ROUND_UP
      );

      const claimableCollateral = collateralRequirement.sub(payoutFromShort);

      const actions = [
        encodeClaimCollateralArgs({
          collateralTokenId: collateralTokenId.toString(),
          amount: optionsAmount.toString(),
        }),
      ];

      const txData = await getSignedTransactionData(
        parseInt((await controller.getNonce(deployer.address)).toString()),
        deployer,
        actions,
        controller.address
      );

      await controller
        .connect(secondAccount)
        .executeMetaTransaction(
          deployer.address,
          actions,
          txData.r,
          txData.s,
          txData.v
        );

      const collateralClaimed = await payoutAsset.balanceOf(deployer.address);

      expect(collateralClaimed).to.equal(claimableCollateral);

      const controllerBalanceAfterClaim = await payoutAsset.balanceOf(
        controller.address
      );

      const intendedControllerBalanceAfterClaim =
        collateralRequirement.sub(claimableCollateral);

      //should ideally be 0, but can also be extra wei due to rounding
      const controllerExtraFunds = controllerBalanceAfterClaim.sub(
        intendedControllerBalanceAfterClaim
      );

      expect(
        parseInt(controllerExtraFunds.toString())
      ).to.be.greaterThanOrEqual(0);
      expect(parseInt(controllerExtraFunds.toString())).to.be.lessThanOrEqual(
        1
      ); //check the rounding is within 1 wei

      await revertToSnapshot(snapshotId);
    });

    it("Users should be able to neutralize positions through meta transactions", async () => {
      const optionsAmount = ethers.utils.parseEther("5");

      const [, collateralRequirement] = await getCollateralRequirement(
        qTokenPut1400,
        nullQToken,
        optionsAmount,
        BN.ROUND_DOWN
      );

      await USDC.connect(assetsRegistryManager).mint(
        deployer.address,
        collateralRequirement
      );

      await USDC.connect(deployer).approve(
        controller.address,
        collateralRequirement
      );

      await controller.connect(deployer).operate([
        encodeMintOptionArgs({
          to: deployer.address,
          qToken: qTokenPut1400.address,
          amount: optionsAmount,
        }),
      ]);

      const collateralTokenId = await collateralToken.getCollateralTokenId(
        qTokenPut1400.address,
        AddressZero
      );

      const amountToNeutralize = ethers.utils.parseEther("3");

      const actions = [
        encodeNeutralizeArgs({
          collateralTokenId: collateralTokenId.toString(),
          amount: amountToNeutralize.toString(),
        }),
      ];

      const txData = await getSignedTransactionData(
        parseInt((await controller.getNonce(deployer.address)).toString()),
        deployer,
        actions,
        controller.address
      );

      await controller
        .connect(secondAccount)
        .executeMetaTransaction(
          deployer.address,
          actions,
          txData.r,
          txData.s,
          txData.v
        );

      expect(await qTokenPut1400.balanceOf(deployer.address)).to.equal(
        optionsAmount.sub(amountToNeutralize)
      );

      expect(
        await collateralToken.balanceOf(deployer.address, collateralTokenId)
      ).to.equal(optionsAmount.sub(amountToNeutralize));
    });

    it("Users should be able to call external functions through meta transactions", async () => {
      const newQTokenParams: optionParameters = [
        WETH.address,
        USDC.address,
        mockOracleManager.address,
        ethers.utils.parseUnits("1000", 6),
        ethers.BigNumber.from(futureTimestamp),
        false,
      ];

      const createOptionCallData = optionsFactory.interface.encodeFunctionData(
        "createOption",
        newQTokenParams
      );

      const actions = [
        encodeCallArgs({
          callee: optionsFactory.address,
          data: createOptionCallData,
        }),
      ];

      const txData = await getSignedTransactionData(
        parseInt((await controller.getNonce(deployer.address)).toString()),
        deployer,
        actions,
        controller.address
      );

      const optionsLength = await optionsFactory.getOptionsLength();
      const targetQTokenAddress = await optionsFactory.getTargetQTokenAddress(
        ...newQTokenParams
      );
      expect(await optionsFactory.getQToken(...newQTokenParams)).to.equal(
        AddressZero
      );
      expect(await optionsFactory.isQToken(targetQTokenAddress)).to.be.false;

      await controller
        .connect(secondAccount)
        .executeMetaTransaction(
          deployer.address,
          actions,
          txData.r,
          txData.s,
          txData.v
        );

      expect(await optionsFactory.getOptionsLength()).to.equal(
        optionsLength.add(1)
      );
      expect(await optionsFactory.getQToken(...newQTokenParams)).to.equal(
        targetQTokenAddress
      );
      expect(await optionsFactory.isQToken(targetQTokenAddress)).to.be.true;
    });

    it("Should revert when trying to make reentrant operate calls through meta transactions", async () => {
      const mintOptionsAction = [
        encodeMintOptionArgs({
          to: secondAccount.address,
          qToken: qTokenCall2000.address,
          amount: ethers.utils.parseEther("10").toString(),
        }),
      ];

      const encodedOperateCallData = controller.interface.encodeFunctionData(
        "operate",
        [mintOptionsAction]
      );

      const reentrantOperateAction = [
        encodeCallArgs({
          callee: controller.address,
          data: encodedOperateCallData,
        }),
      ];

      const txData = await getSignedTransactionData(
        parseInt((await controller.getNonce(deployer.address)).toString()),
        deployer,
        reentrantOperateAction,
        controller.address
      );

      await expect(
        controller
          .connect(secondAccount)
          .executeMetaTransaction(
            deployer.address,
            reentrantOperateAction,
            txData.r,
            txData.s,
            txData.v
          )
      ).to.be.revertedWith("unsuccessful function call");
    });

    it("Should revert when trying to call internal methods through meta transactions", async () => {
      const mintOptionsPositionCallData = `${web3.eth.abi.encodeFunctionSignature(
        "_mintOptionsPosition((address,address,uint256))"
      )}${web3.eth.abi
        .encodeParameter("tuple(address,address,uint256)", [
          secondAccount.address,
          qTokenCall2000.address,
          ethers.utils.parseEther("1"),
        ])
        .slice(2)}`;

      const actions = [
        encodeCallArgs({
          callee: controller.address,
          data: mintOptionsPositionCallData,
        }),
      ];

      const txData = await getSignedTransactionData(
        parseInt((await controller.getNonce(deployer.address)).toString()),
        deployer,
        actions,
        controller.address
      );

      await expect(
        controller
          .connect(secondAccount)
          .executeMetaTransaction(
            deployer.address,
            actions,
            txData.r,
            txData.s,
            txData.v
          )
      ).to.be.revertedWith("unsuccessful function call");
    });
  });

  describe("Upgradeability", () => {
    const upgradeController = async (
      controller: Controller
    ): Promise<ControllerV2> => {
      const ControllerV2 = await ethers.getContractFactory("ControllerV2");
      const controllerV2 = <ControllerV2>(
        await upgrades.upgradeProxy(controller.address, ControllerV2)
      );
      return controllerV2;
    };
    it("Should maintain state after upgrades", async () => {
      const configuredOptionsFactory = await controller.optionsFactory();

      const controllerV2 = await upgradeController(controller);

      expect(await controllerV2.optionsFactory()).to.equal(
        configuredOptionsFactory
      );
    });

    it("Should be able to add new state variables through upgrades", async () => {
      const controllerV2 = await upgradeController(controller);

      expect(await controllerV2.newV2StateVariable()).to.equal(Zero);
    });

    it("Should be able to add new functions through upgrades", async () => {
      const controllerV2 = await upgradeController(controller);

      expect(await controllerV2.newV2StateVariable()).to.equal(Zero);

      await controllerV2.connect(deployer).setNewV2StateVariable(42);

      expect(await controllerV2.newV2StateVariable()).to.equal(
        ethers.BigNumber.from("42")
      );
    });
  });
});
