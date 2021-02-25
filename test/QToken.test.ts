import { MockContract } from "ethereum-waffle";
import { Signer } from "ethers";
import { ethers, waffle } from "hardhat";
import { beforeEach, describe, it } from "mocha";
import QTokenJSON from "../artifacts/contracts/protocol/options/QToken.sol/QToken.json";
import { QToken } from "../typechain/QToken";
import { QuantConfig } from "../typechain/QuantConfig";
import { expect, provider } from "./setup";
import { deployQToken, deployQuantConfig, mockERC20 } from "./testUtils";

const { deployContract } = waffle;

describe("QToken", () => {
  let quantConfig: QuantConfig;
  let qToken: QToken;
  let admin: Signer;
  let secondAccount: Signer;
  let USDC: MockContract;
  let WETH: MockContract;
  let userAddress: string;
  const expiryTime = ethers.BigNumber.from("1618592400"); // April 16th, 2021
  const strkePrice = ethers.utils.parseEther("1400");
  const oracle = ethers.constants.AddressZero;

  const mintOptionsToAccount = async (account: string, amount: number) => {
    await qToken
      .connect(admin)
      .mint(account, ethers.utils.parseEther(amount.toString()));
  };

  beforeEach(async () => {
    [admin, secondAccount] = provider.getWallets();
    userAddress = await secondAccount.getAddress();

    quantConfig = await deployQuantConfig(admin);

    USDC = await mockERC20(admin, "USDC");
    WETH = await mockERC20(admin, "WETH");

    qToken = await deployQToken(
      admin,
      quantConfig,
      WETH.address,
      USDC.address,
      oracle,
      strkePrice,
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
    expect(await qToken.strikePrice()).to.equal(strkePrice);
    expect(await qToken.expiryTime()).to.equal(expiryTime);
    expect(await qToken.isCall()).to.be.false;
  });

  it("Admin should be able to mint options", async () => {
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

  it("Admin should be able to burn options", async () => {
    await mintOptionsToAccount(userAddress, 4);
    const previousBalance = await qToken.balanceOf(userAddress);

    // Burn options from the user address
    await qToken.connect(admin).burn(userAddress, ethers.utils.parseEther("2"));

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
    ).to.be.revertedWith("QToken: Only the OptionsFactory can mint QTokens");
  });

  it("Should revert when an unauthorized account tries to burn options", async () => {
    await expect(
      qToken
        .connect(secondAccount)
        .burn(await admin.getAddress(), ethers.BigNumber.from("4"))
    ).to.be.revertedWith("QToken: Only the OptionsFactory can burn QTokens");
  });

  it("Should create CALL options with different parameters", async () => {
    qToken = <QToken>(
      await deployContract(admin, QTokenJSON, [
        quantConfig.address,
        WETH.address,
        USDC.address,
        oracle,
        ethers.BigNumber.from("1912340000000000000000"),
        ethers.BigNumber.from("1630768904"),
        true,
      ])
    );
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
        await deployContract(admin, QTokenJSON, [
          quantConfig.address,
          WETH.address,
          USDC.address,
          oracle,
          strkePrice,
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
});
