import { MockContract } from "ethereum-waffle";
import { Signer } from "ethers";
import { ethers, upgrades, waffle } from "hardhat";
import { beforeEach, describe, it } from "mocha";
import ERC20 from "../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json";
import QTokenJSON from "../artifacts/contracts/protocol/options/QToken.sol/QToken.json";
import { QToken } from "../typechain/QToken";
import { QuantConfig } from "../typechain/QuantConfig";
import { expect, provider } from "./setup";

const { deployContract, deployMockContract } = waffle;

describe("QToken", () => {
  let quantConfig: QuantConfig;
  let qToken: QToken;
  let admin: Signer;
  let secondAccount: Signer;
  let USDC: MockContract;
  let WETH: MockContract;
  let userAddress: string;
  const timestamp = ethers.BigNumber.from("1618592400"); // April 16th, 2021
  const strkePrice = ethers.utils.parseEther("1400");
  const oracle = ethers.constants.AddressZero;

  const createSamplePutOption = async () => {
    const qToken = <QToken>(
      await deployContract(admin, QTokenJSON, [
        quantConfig.address,
        WETH.address,
        USDC.address,
        oracle,
        strkePrice,
        timestamp,
        false,
      ])
    );

    return qToken;
  };

  const mintOptionsToAccount = async (account: string, amount: number) => {
    await qToken
      .connect(admin)
      .mint(account, ethers.utils.parseEther(amount.toString()));
  };

  beforeEach(async () => {
    [admin, secondAccount] = provider.getWallets();
    userAddress = await secondAccount.getAddress();
    const QuantConfig = await ethers.getContractFactory("QuantConfig");
    quantConfig = <QuantConfig>(
      await upgrades.deployProxy(QuantConfig, [await admin.getAddress()])
    );

    USDC = await deployMockContract(admin, ERC20.abi);
    await USDC.mock.symbol.returns("USDC");

    WETH = await deployMockContract(admin, ERC20.abi);
    await WETH.mock.symbol.returns("WETH");

    qToken = await createSamplePutOption();
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
    expect(await qToken.expiryTime()).to.equal(timestamp);
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
});
