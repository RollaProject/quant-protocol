import { BigNumber, Signer } from "ethers";
import { ethers, waffle } from "hardhat";
import { beforeEach, describe, it } from "mocha";
import QTokenJSON from "../artifacts/contracts/protocol/options/QToken.sol/QToken.json";
import { MockERC20 } from "../typechain/MockERC20";
import { QToken } from "../typechain/QToken";
import { QuantConfig } from "../typechain/QuantConfig";
import { expect, provider } from "./setup";
import {
  deployAssetsRegistry,
  deployQToken,
  deployQuantConfig,
  mockERC20,
} from "./testUtils";

const { deployContract } = waffle;

describe("QToken", async () => {
  let quantConfig: QuantConfig;
  let qToken: QToken;
  let timelockController: Signer;
  let secondAccount: Signer;
  let assetsRegistryManager: Signer;
  let optionsMinter: Signer;
  let optionsBurner: Signer;
  let USDC: MockERC20;
  let WETH: MockERC20;
  let userAddress: string;
  let scaledStrikePrice: BigNumber;
  const strikePrice = ethers.utils.parseUnits("1400", 6);
  const expiryTime = ethers.BigNumber.from("1618592400"); // April 16th, 2021
  const oracle = ethers.constants.AddressZero;

  const mintOptionsToAccount = async (account: string, amount: number) => {
    await qToken
      .connect(optionsMinter)
      .mint(account, ethers.utils.parseEther(amount.toString()));
  };

  beforeEach(async () => {
    [
      timelockController,
      secondAccount,
      assetsRegistryManager,
      optionsMinter,
      optionsBurner,
    ] = provider.getWallets();
    userAddress = await secondAccount.getAddress();

    quantConfig = await deployQuantConfig(timelockController, [
      {
        addresses: [await assetsRegistryManager.getAddress()],
        role: ethers.utils.id("ASSET_REGISTRY_MANAGER_ROLE"),
      },
      {
        addresses: [await optionsMinter.getAddress()],
        role: ethers.utils.id("OPTIONS_MINTER_ROLE"),
      },
      {
        addresses: [await optionsBurner.getAddress()],
        role: ethers.utils.id("OPTIONS_BURNER_ROLE"),
      },
    ]);

    WETH = await mockERC20(timelockController, "WETH", "Wrapped Ether");
    USDC = await mockERC20(timelockController, "USDC", "USD Coin", 6);

    const assetsRegistry = await deployAssetsRegistry(
      timelockController,
      quantConfig
    );

    await assetsRegistry
      .connect(assetsRegistryManager)
      .addAsset(WETH.address, "", "", 0, 1000);
    await assetsRegistry
      .connect(assetsRegistryManager)
      .addAsset(USDC.address, "", "", 0, 1000);

    scaledStrikePrice = ethers.utils.parseUnits("1400", await USDC.decimals());

    qToken = await deployQToken(
      timelockController,
      quantConfig,
      WETH.address,
      USDC.address,
      oracle,
      strikePrice,
      expiryTime,
      false
    );
  });

  it("Should be able to create a new option", async () => {
    expect(await qToken.symbol()).to.equal("QUANT-WETH-USDC-16APR21-1400-P");
    expect(await qToken.name()).to.equal(
      "QUANT WETH-USDC 16-April-2021 1400 Put"
    );
    expect(await qToken.quantConfig()).to.equal(quantConfig.address);
    expect(await qToken.underlyingAsset()).to.equal(WETH.address);
    expect(await qToken.strikeAsset()).to.equal(USDC.address);
    expect(await qToken.oracle()).to.equal(oracle);
    expect(await qToken.strikePrice()).to.equal(scaledStrikePrice);
    expect(await qToken.expiryTime()).to.equal(expiryTime);
    expect(await qToken.isCall()).to.be.false;
  });

  it("Options minter should be able to mint options", async () => {
    // User balance should be zero before minting the options
    expect(await qToken.balanceOf(userAddress)).to.equal(
      ethers.BigNumber.from("0")
    );

    // Mint options to the user address
    await mintOptionsToAccount(userAddress, 2);

    // User balance should have increased
    expect(await qToken.balanceOf(userAddress)).to.equal(
      ethers.utils.parseEther("2")
    );
  });

  it("Opitons burner should be able to burn options", async () => {
    await mintOptionsToAccount(userAddress, 4);
    const previousBalance = await qToken.balanceOf(userAddress);

    // Burn options from the user address
    await qToken
      .connect(optionsBurner)
      .burn(userAddress, ethers.utils.parseEther("2"));

    const newBalance = await qToken.balanceOf(userAddress);

    expect(parseInt(newBalance.toString())).to.be.lessThan(
      parseInt(previousBalance.toString())
    );
  });

  it("Should revert when an unauthorized account tries to mint options", async () => {
    await expect(
      qToken
        .connect(secondAccount)
        .mint(userAddress, ethers.utils.parseEther("2"))
    ).to.be.revertedWith("QToken: Only an options minter can mint QTokens");
  });

  it("Should revert when an unauthorized account tries to burn options", async () => {
    await expect(
      qToken
        .connect(secondAccount)
        .burn(await timelockController.getAddress(), ethers.BigNumber.from("4"))
    ).to.be.revertedWith("QToken: Only an options burner can burn QTokens");
  });

  it("Should create CALL options with different parameters", async () => {
    qToken = <QToken>await deployContract(timelockController, QTokenJSON, [
      quantConfig.address,
      WETH.address,
      USDC.address,
      oracle,
      ethers.BigNumber.from("1912340000"), // USDC has 6 decimals
      ethers.BigNumber.from("1630768904"),
      true,
    ]);
    expect(await qToken.symbol()).to.equal("QUANT-WETH-USDC-04SEP21-1912.44-C");
    expect(await qToken.name()).to.equal(
      "QUANT WETH-USDC 04-September-2021 1912.44 Call"
    );
  });

  it("Should be able to create options expiring on any month", async () => {
    const months: { [month: string]: string } = {
      JAN: "January",
      FEB: "February",
      MAR: "March",
      APR: "April",
      MAY: "May",
      JUN: "June",
      JUL: "July",
      AUG: "August",
      SEP: "September",
      OCT: "October",
      NOV: "November",
      DEC: "December",
    };

    const getMonth = async (
      optionToken: QToken,
      optionMetadata: string,
      isMetadataAMonthName = true
    ): Promise<string> => {
      if (isMetadataAMonthName) {
        // e.g., January
        return (await optionToken.name()).split(" ")[2].split("-")[1];
      }
      // it's a string like JAN
      return (await optionToken.symbol()).split("-", 4)[3].slice(2, 5);
    };

    let optionexpiryTime = 1609773704;
    const aMonthInSeconds = 2629746;
    for (const month in months) {
      qToken = <QToken>(
        await deployContract(timelockController, QTokenJSON, [
          quantConfig.address,
          WETH.address,
          USDC.address,
          oracle,
          strikePrice,
          ethers.BigNumber.from(optionexpiryTime.toString()),
          false,
        ])
      );

      expect(await getMonth(qToken, await qToken.name())).to.equal(
        months[month]
      );

      expect(await getMonth(qToken, await qToken.symbol(), false)).to.equal(
        month
      );

      optionexpiryTime += aMonthInSeconds;
    }
  });

  it("Should emit the QTokenMinted event", async () => {
    await expect(qToken.connect(optionsMinter).mint(userAddress, 4))
      .to.emit(qToken, "QTokenMinted")
      .withArgs(userAddress, 4);
  });

  it("Should emit the QTokenBurned event", async () => {
    await mintOptionsToAccount(userAddress, 6);
    await expect(qToken.connect(optionsBurner).burn(userAddress, 3))
      .to.emit(qToken, "QTokenBurned")
      .withArgs(userAddress, 3);
  });

  // TODO: Test the ACTIVE status
  // it("Should return an ACTIVE status for options that haven't expired yet", async () => {});
});
