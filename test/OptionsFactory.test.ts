import { deployMockContract } from "@ethereum-waffle/mock-contract";
import { MockContract } from "ethereum-waffle";
import { BigNumber, Signer } from "ethers";
import { ethers } from "hardhat";
import { beforeEach, describe } from "mocha";
import ORACLE_MANAGER from "../artifacts/contracts/pricing/oracle/ChainlinkOracleManager.sol/ChainlinkOracleManager.json";
import PRICE_REGISTRY from "../artifacts/contracts/pricing/PriceRegistry.sol/PriceRegistry.json";
import {
  AssetsRegistry,
  Controller,
  OptionsFactory,
  OracleRegistry,
} from "../typechain";
import { CollateralToken } from "../typechain/CollateralToken";
import { MockERC20 } from "../typechain/MockERC20";
import { expect, provider } from "./setup";
import {
  deployAssetsRegistry,
  deployOracleRegistry,
  erc1155Uri,
  mockERC20,
  name,
  version,
} from "./testUtils";

describe("OptionsFactory", () => {
  let collateralToken: CollateralToken;
  let deployer: Signer;
  let secondAccount: Signer;
  let WETH: MockERC20;
  let BUSD: MockERC20;
  let optionsFactory: OptionsFactory;
  let assetsRegistry: AssetsRegistry;
  let oracleRegistry: OracleRegistry;
  let mockOracleManager: MockContract;
  let futureTimestamp: number;
  let samplePutOptionParameters: [
    string,
    string,
    BigNumber,
    boolean,
    BigNumber
  ];
  let sampleCollateralTokenParameters: [
    string,
    string,
    string,
    BigNumber,
    boolean,
    BigNumber
  ];

  beforeEach(async () => {
    [deployer, secondAccount] = provider.getWallets();

    WETH = await mockERC20(deployer, "WETH", "Wrapped Ether");
    BUSD = await mockERC20(deployer, "BUSD", "BUSD Token", 18);

    mockOracleManager = await deployMockContract(deployer, ORACLE_MANAGER.abi);

    assetsRegistry = await deployAssetsRegistry(deployer);
    await assetsRegistry
      .connect(deployer)
      .addAssetWithOptionalERC20Methods(BUSD.address);
    await assetsRegistry
      .connect(deployer)
      .addAssetWithOptionalERC20Methods(WETH.address);

    oracleRegistry = await deployOracleRegistry(deployer);

    await oracleRegistry.connect(deployer).addOracle(mockOracleManager.address);

    await oracleRegistry
      .connect(deployer)
      .activateOracle(mockOracleManager.address);

    const mockPriceRegistry = await deployMockContract(
      deployer,
      PRICE_REGISTRY.abi
    );

    await mockPriceRegistry.mock.oracleRegistry.returns(oracleRegistry.address);

    const Controller = await ethers.getContractFactory("Controller");
    const controller = <Controller>(
      await Controller.deploy(
        name,
        version,
        erc1155Uri,
        oracleRegistry.address,
        BUSD.address,
        mockPriceRegistry.address,
        assetsRegistry.address
      )
    );

    const CollateralToken = await ethers.getContractFactory("CollateralToken");
    collateralToken = <CollateralToken>(
      CollateralToken.attach(await controller.collateralToken())
    );

    const OptionsFactory = await ethers.getContractFactory("OptionsFactory");
    optionsFactory = <OptionsFactory>(
      OptionsFactory.attach(await controller.optionsFactory())
    );

    //Note: returning any address here to show existence of the oracle
    await mockOracleManager.mock.getAssetOracle.returns(
      mockOracleManager.address
    );

    await mockOracleManager.mock.isValidOption.returns(true);

    // 30 days from now
    futureTimestamp = Math.floor(Date.now() / 1000) + 30 * 24 * 3600;

    samplePutOptionParameters = [
      WETH.address,
      mockOracleManager.address,
      ethers.BigNumber.from(futureTimestamp),
      false,
      ethers.utils.parseUnits("1400", await BUSD.decimals()),
    ];

    sampleCollateralTokenParameters = [
      WETH.address,
      ethers.constants.AddressZero,
      mockOracleManager.address,
      ethers.BigNumber.from(futureTimestamp),
      false,
      ethers.utils.parseUnits("1400", await BUSD.decimals()),
    ];
  });

  describe("createOption", () => {
    it("Anyone should be able to create new options", async () => {
      expect(await optionsFactory.getOptionsLength()).to.equal(
        ethers.BigNumber.from("0")
      );

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
          ...samplePutOptionParameters,
          collateralTokenId,
          ethers.BigNumber.from("1")
        );

      expect(await optionsFactory.qTokens(ethers.BigNumber.from("0"))).to.equal(
        qTokenAddress
      );

      expect(
        await collateralToken.collateralTokenIds(ethers.BigNumber.from("0"))
      ).to.equal(collateralTokenId);
    });

    it("Should revert when trying to create an option if the oracle is not registered in the oracle registry", async () => {
      await expect(
        optionsFactory
          .connect(secondAccount)
          .createOption(
            WETH.address,
            ethers.constants.AddressZero,
            ethers.BigNumber.from(futureTimestamp),
            false,
            ethers.utils.parseUnits("1400", await BUSD.decimals())
          )
      ).to.be.revertedWith(
        "OptionsFactory: Oracle is not registered in OracleRegistry"
      );
    });

    it("Should revert when trying to make an option for an asset not registered in the oracle", async () => {
      //Set the oracle to the zero address, signifying the asset not being registed
      await mockOracleManager.mock.getAssetOracle.returns(
        ethers.constants.AddressZero
      );

      await expect(
        optionsFactory
          .connect(secondAccount)
          .createOption(
            WETH.address,
            mockOracleManager.address,
            ethers.BigNumber.from(futureTimestamp),
            false,
            ethers.utils.parseUnits("1400", await BUSD.decimals())
          )
      ).to.be.revertedWith("OptionsFactory: Asset does not exist in oracle");
    });

    it("Should revert when trying to create an option with a deactivated oracle", async () => {
      //Deactivate the oracle
      await oracleRegistry
        .connect(deployer)
        .deactivateOracle(mockOracleManager.address);

      await expect(
        optionsFactory
          .connect(secondAccount)
          .createOption(
            WETH.address,
            mockOracleManager.address,
            ethers.BigNumber.from(futureTimestamp),
            false,
            ethers.utils.parseUnits("1400", await BUSD.decimals())
          )
      ).to.be.revertedWith(
        "OptionsFactory: Oracle is not active in the OracleRegistry"
      );
    });

    it("Should revert when trying to create an option that would have already expired", async () => {
      const pastTimestamp = "1582602164";
      await expect(
        optionsFactory.createOption(
          WETH.address,
          ethers.constants.AddressZero,
          ethers.BigNumber.from(pastTimestamp),
          false,
          ethers.utils.parseUnits("1400", await BUSD.decimals())
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
      ).to.be.revertedWith("option already created");
    });

    it("Should revert when trying to create a PUT option with a strike price of 0", async () => {
      await expect(
        optionsFactory
          .connect(secondAccount)
          .createOption(
            WETH.address,
            mockOracleManager.address,
            futureTimestamp,
            false,
            ethers.BigNumber.from("0")
          )
      ).to.be.revertedWith("strike can't be 0");
    });

    it("Should revert when trying to create a CALL option with a strike price of 0", async () => {
      await expect(
        optionsFactory
          .connect(secondAccount)
          .createOption(
            WETH.address,
            mockOracleManager.address,
            futureTimestamp,
            true,
            ethers.BigNumber.from("0")
          )
      ).to.be.revertedWith("strike can't be 0");
    });

    it("Should revert when trying to create an option with an underlying that's not in the assets registry", async () => {
      await expect(
        optionsFactory
          .connect(secondAccount)
          .createOption(
            ethers.constants.AddressZero,
            mockOracleManager.address,
            futureTimestamp,
            false,
            ethers.utils.parseUnits("1400", await BUSD.decimals())
          )
      ).to.be.revertedWith("underlying not in the registry");
    });

    it("Should revert when trying to create an option that is considered invalid by the given oracle", async () => {
      await mockOracleManager.mock.isValidOption.returns(false);
      await expect(
        optionsFactory
          .connect(secondAccount)
          .createOption(
            ethers.constants.AddressZero,
            mockOracleManager.address,
            futureTimestamp,
            false,
            ethers.utils.parseUnits("1400", await BUSD.decimals())
          )
      ).to.be.revertedWith(
        "OptionsFactory: Oracle doesn't support the given option"
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
