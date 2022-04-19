import { deployMockContract, MockContract } from "ethereum-waffle";
import { ecsign } from "ethereumjs-util";
import { BigNumber, Signer, Wallet } from "ethers";
import { ethers, waffle } from "hardhat";
import { beforeEach, describe, it } from "mocha";
import QTokenJSON from "../artifacts/contracts/options/QToken.sol/QToken.json";
import PriceRegistryJSON from "../artifacts/contracts/pricing/PriceRegistry.sol/PriceRegistry.json";
import { AssetsRegistry } from "../typechain";
import { MockERC20 } from "../typechain/MockERC20";
import { QToken } from "../typechain/QToken";
import { expect, provider } from "./setup";
import {
  deployAssetsRegistry,
  deployQToken,
  getApprovalDigest,
  mockERC20,
} from "./testUtils";

const { deployContract } = waffle;

const { keccak256, defaultAbiCoder, toUtf8Bytes, hexlify } = ethers.utils;
const TEST_AMOUNT = ethers.utils.parseEther("10");

describe("QToken", async () => {
  let qToken: QToken;
  let deployer: Signer;
  let secondAccount: Wallet;
  let otherAccount: Signer;
  let BUSD: MockERC20;
  let WETH: MockERC20;
  let DOGE: MockERC20;
  let mockPriceRegistry: MockContract;
  let assetsRegistry: AssetsRegistry;
  let userAddress: string;
  let otherUserAddress: string;
  let scaledStrikePrice: BigNumber;
  let qTokenParams: [string, string, string, BigNumber, boolean, BigNumber];
  const strikePrice = ethers.utils.parseUnits("1400", 18);
  const expiryTime = ethers.BigNumber.from("1618592400"); // April 16th, 2021
  const oracle = ethers.Wallet.createRandom().address;

  const mintOptionsToAccount = async (account: string, amount: number) => {
    await qToken
      .connect(deployer)
      .mint(account, ethers.utils.parseEther(amount.toString()));
  };

  enum PriceStatus {
    ACTIVE,
    AWAITING_SETTLEMENT_PRICE,
    SETTLED,
  }

  beforeEach(async () => {
    [deployer, secondAccount, deployer, deployer, deployer, otherAccount] =
      provider.getWallets();
    userAddress = await secondAccount.getAddress();
    otherUserAddress = await otherAccount.getAddress();

    WETH = await mockERC20(deployer, "WETH", "Wrapped Ether");
    BUSD = await mockERC20(deployer, "BUSD", "BUSD Token", 18);
    DOGE = await mockERC20(deployer, "DOGE", "DOGE Coin", 8);

    assetsRegistry = await deployAssetsRegistry(deployer);

    await assetsRegistry
      .connect(deployer)
      .addAssetWithOptionalERC20Methods(WETH.address);
    await assetsRegistry
      .connect(deployer)
      .addAssetWithOptionalERC20Methods(BUSD.address);
    await assetsRegistry
      .connect(deployer)
      .addAssetWithOptionalERC20Methods(DOGE.address);

    scaledStrikePrice = ethers.utils.parseUnits("1400", await BUSD.decimals());

    mockPriceRegistry = await deployMockContract(
      deployer,
      PriceRegistryJSON.abi
    );

    qTokenParams = [
      WETH.address,
      BUSD.address,
      oracle,
      expiryTime,
      false,
      strikePrice,
    ];

    qToken = await deployQToken(
      deployer,
      WETH.address,
      BUSD.address,
      mockPriceRegistry.address,
      assetsRegistry.address,
      oracle,
      expiryTime,
      false,
      strikePrice
    );
  });

  it("Should be able to create a new option", async () => {
    expect(await qToken.symbol()).to.equal("ROLLA-WETH-16APR2021-1400-P");
    expect(await qToken.name()).to.equal("ROLLA WETH 16-April-2021 1400 Put");
    expect(await qToken.underlyingAsset()).to.equal(WETH.address);
    expect(await qToken.strikeAsset()).to.equal(BUSD.address);
    expect(await qToken.oracle()).to.equal(oracle);
    expect(await qToken.strikePrice()).to.equal(scaledStrikePrice);
    expect(await qToken.expiryTime()).to.equal(expiryTime);
    expect(await qToken.isCall()).to.be.false;
    expect(await qToken.decimals()).to.equal(ethers.BigNumber.from("18"));
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
      .connect(deployer)
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
    ).to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("Should revert when an unauthorized account tries to burn options", async () => {
    await expect(
      qToken
        .connect(secondAccount)
        .burn(await deployer.getAddress(), ethers.BigNumber.from("4"))
    ).to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("Should create CALL options with different parameters", async () => {
    qToken = <QToken>await deployContract(deployer, QTokenJSON, [
      WETH.address,
      BUSD.address,
      mockPriceRegistry.address,
      assetsRegistry.address,
      oracle,
      ethers.BigNumber.from("1630768904"),
      true,
      ethers.BigNumber.from("1912340000000000000000"), // BUSD has 18 decimals
    ]);
    expect(await qToken.symbol()).to.equal("ROLLA-WETH-04SEP2021-1912.34-C");
    expect(await qToken.name()).to.equal(
      "ROLLA WETH 04-September-2021 1912.34 Call"
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
      return (await optionToken.symbol()).split("-", 4)[2].slice(2, 5);
    };

    let optionexpiryTime = 1609773704;
    const aMonthInSeconds = 2629746;
    for (const month in months) {
      qToken = <QToken>(
        await deployContract(deployer, QTokenJSON, [
          WETH.address,
          BUSD.address,
          mockPriceRegistry.address,
          assetsRegistry.address,
          oracle,
          ethers.BigNumber.from(optionexpiryTime.toString()),
          false,
          strikePrice,
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
    await expect(qToken.connect(deployer).mint(userAddress, 4))
      .to.emit(qToken, "QTokenMinted")
      .withArgs(userAddress, 4);
  });

  it("Should emit the QTokenBurned event", async () => {
    await mintOptionsToAccount(userAddress, 6);
    await expect(qToken.connect(deployer).burn(userAddress, 3))
      .to.emit(qToken, "QTokenBurned")
      .withArgs(userAddress, 3);
  });

  it("Should return an ACTIVE status for options that haven't expired yet", async () => {
    const nonExpiredQToken = await deployQToken(
      deployer,
      WETH.address,
      BUSD.address,
      mockPriceRegistry.address,
      assetsRegistry.address,
      ethers.Wallet.createRandom().address,
      ethers.BigNumber.from(
        (Math.round(Date.now() / 1000) + 30 * 24 * 3600).toString()
      ),
      false,
      strikePrice
    );

    expect(await nonExpiredQToken.getOptionPriceStatus()).to.equal(
      PriceStatus.ACTIVE
    );
  });

  it("Should be created with the right EIP-2612 (permit) configuration", async () => {
    expect(await qToken.DOMAIN_SEPARATOR()).to.equal(
      keccak256(
        defaultAbiCoder.encode(
          ["bytes32", "bytes32", "bytes32", "uint256", "address"],
          [
            keccak256(
              toUtf8Bytes(
                "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
              )
            ),
            keccak256(toUtf8Bytes(await qToken.name())),
            keccak256(toUtf8Bytes("1")),
            provider.network.chainId,
            qToken.address,
          ]
        )
      )
    );
  });

  it("Should be able to set allowance and then transfer options through the permit functionality", async () => {
    const nonce = await qToken.nonces(userAddress);
    const deadline = ethers.constants.MaxUint256;
    const digest = await getApprovalDigest(
      qToken,
      { owner: userAddress, spender: otherUserAddress, value: TEST_AMOUNT },
      nonce,
      deadline
    );

    const { v, r, s } = ecsign(
      Buffer.from(digest.slice(2), "hex"),
      Buffer.from(secondAccount.privateKey.slice(2), "hex")
    );

    await expect(
      qToken.permit(
        userAddress,
        otherUserAddress,
        TEST_AMOUNT,
        deadline,
        v,
        hexlify(r),
        hexlify(s)
      )
    )
      .to.emit(qToken, "Approval")
      .withArgs(userAddress, otherUserAddress, TEST_AMOUNT);
    expect(await qToken.allowance(userAddress, otherUserAddress)).to.equal(
      TEST_AMOUNT
    );
    expect(await qToken.nonces(userAddress)).to.equal(
      ethers.BigNumber.from("1")
    );

    await qToken.connect(deployer).mint(userAddress, TEST_AMOUNT);
    expect(await qToken.balanceOf(userAddress)).to.equal(TEST_AMOUNT);
    const recipient = await deployer.getAddress();
    expect(await qToken.balanceOf(recipient)).to.equal(ethers.constants.Zero);

    await qToken
      .connect(otherAccount)
      .transferFrom(userAddress, recipient, TEST_AMOUNT);
    expect(await qToken.balanceOf(userAddress)).to.equal(ethers.constants.Zero);
    expect(await qToken.balanceOf(recipient)).to.equal(TEST_AMOUNT);
    expect(await qToken.allowance(userAddress, otherUserAddress)).to.equal(
      ethers.constants.Zero
    );
  });

  it("Should return the correct details of an option", async () => {
    expect(await qToken.getQTokenInfo()).to.eql(qTokenParams);
  });

  it("Should generate the right strike price string for decimal numbers", async () => {
    const decimalStrikePrice = ethers.utils.parseEther("10000.90001");
    const expiryTime = ethers.BigNumber.from("2153731385"); // Thu Apr 01 2038 10:43:05 GMT+0000

    const decimalStrikeQToken = await deployQToken(
      deployer,
      WETH.address,
      BUSD.address,
      mockPriceRegistry.address,
      assetsRegistry.address,
      oracle,
      expiryTime,
      false,
      decimalStrikePrice
    );

    expect(await decimalStrikeQToken.name()).to.equal(
      "ROLLA WETH 01-April-2038 10000.90001 Put"
    );
    expect(await decimalStrikeQToken.symbol()).to.equal(
      "ROLLA-WETH-01APR2038-10000.90001-P"
    );
  });

  it("Should generate the right strike price for different tokens and decimal numbers", async () => {
    const weiStrikePrice = ethers.BigNumber.from("1000000000000000001");
    const weiStrikePriceQToken = await deployQToken(
      deployer,
      WETH.address,
      BUSD.address,
      mockPriceRegistry.address,
      assetsRegistry.address,
      oracle,
      ethers.BigNumber.from("2153731385"),
      false,
      weiStrikePrice
    );

    expect(await weiStrikePriceQToken.name()).to.equal(
      "ROLLA WETH 01-April-2038 1.000000000000000001 Put"
    );
    expect(await weiStrikePriceQToken.symbol()).to.equal(
      "ROLLA-WETH-01APR2038-1.000000000000000001-P"
    );

    const dogeStrikePrice = ethers.utils.parseEther("0.135921");
    const dogeQToken = await deployQToken(
      deployer,
      DOGE.address,
      BUSD.address,
      mockPriceRegistry.address,
      assetsRegistry.address,
      oracle,
      ethers.BigNumber.from("2153731385"),
      false,
      dogeStrikePrice
    );

    expect(await dogeQToken.name()).to.eql(
      "ROLLA DOGE 01-April-2038 0.135921 Put"
    );
    expect(await dogeQToken.symbol()).to.eql("ROLLA-DOGE-01APR2038-0.135921-P");
  });
});
