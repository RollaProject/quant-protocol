import { Contract, Signer, Wallet } from "ethers";
import { ethers } from "hardhat";
import { beforeEach, describe, it } from "mocha";
import { CollateralToken } from "../typechain/CollateralToken";
import { MockERC20 } from "../typechain/MockERC20";
import { QToken } from "../typechain/QToken";
import { expect, provider } from "./setup";
import {
  deployAssetsRegistry,
  deployCollateralToken,
  deployOracleRegistry,
  deployQToken,
  deploySimpleOptionsFactory,
  getApprovalForAllSignedData,
  mockERC20,
} from "./testUtils";

describe("CollateralToken", () => {
  let collateralToken: CollateralToken;
  let qToken: QToken;
  let secondQToken: QToken;
  let deployer: Wallet;
  let secondAccount: Wallet;
  let userAddress: string;
  let WETH: MockERC20;
  let BUSD: MockERC20;
  let priceRegistry: Contract;
  let assetsRegistry: Contract;

  const createCollateralToken = async (
    account: Signer,
    qToken: QToken,
    qTokenAsCollateral?: string
  ) => {
    if (qTokenAsCollateral) {
      await collateralToken
        .connect(account)
        .createSpreadCollateralToken(qToken.address, qTokenAsCollateral);
    } else {
      await collateralToken
        .connect(account)
        .createOptionCollateralToken(qToken.address);
    }
  };

  beforeEach(async () => {
    [deployer, secondAccount] = provider.getWallets();
    userAddress = await secondAccount.getAddress();

    WETH = await mockERC20(deployer, "WETH");
    BUSD = await mockERC20(deployer, "BUSD");

    assetsRegistry = await deployAssetsRegistry(deployer);

    await assetsRegistry
      .connect(deployer)
      .addAssetWithOptionalERC20Methods(WETH.address);
    await assetsRegistry
      .connect(deployer)
      .addAssetWithOptionalERC20Methods(BUSD.address);

    const oracleRegistry = await deployOracleRegistry(deployer);

    const PriceRegistry = await ethers.getContractFactory("PriceRegistry");
    priceRegistry = await PriceRegistry.deploy(
      await BUSD.decimals(),
      oracleRegistry.address
    );

    const oracle = ethers.Wallet.createRandom().address;

    const simpleOptionsFactory = await deploySimpleOptionsFactory(
      assetsRegistry.address
    );

    qToken = await deployQToken(
      deployer,
      WETH.address,
      BUSD.address,
      simpleOptionsFactory,
      assetsRegistry.address,
      oracle
    );

    secondQToken = await deployQToken(
      deployer,
      WETH.address,
      BUSD.address,
      simpleOptionsFactory,
      assetsRegistry.address,
      ethers.Wallet.createRandom().address,
      ethers.BigNumber.from("1618592400"),
      true,
      ethers.utils.parseUnits("2000", await BUSD.decimals())
    );

    collateralToken = await deployCollateralToken(deployer);
  });

  describe("metaSetApprovalForAll", () => {
    const futureTimestamp = Math.round(Date.now() / 1000) + 3600 * 24;
    let nonce: number;

    beforeEach(async () => {
      nonce = parseInt(
        (await collateralToken.nonces(deployer.address)).toString()
      );
    });
    it("Should revert when passing an expired deadline", async () => {
      const pastTimestamp = Math.round(Date.now() / 1000) - 3600 * 24; // a day in the past

      await expect(
        collateralToken
          .connect(secondAccount)
          .metaSetApprovalForAll(
            deployer.address,
            secondAccount.address,
            true,
            nonce,
            pastTimestamp,
            0,
            ethers.constants.HashZero,
            ethers.constants.HashZero
          )
      ).to.be.revertedWith("CollateralToken: expired deadline");
    });

    it("Should revert when passing an invalid signature", async () => {
      await expect(
        collateralToken
          .connect(secondAccount)
          .metaSetApprovalForAll(
            deployer.address,
            secondAccount.address,
            true,
            nonce,
            futureTimestamp,
            0,
            ethers.constants.HashZero,
            ethers.constants.HashZero
          )
      ).to.be.revertedWith("ECDSA: invalid signature 'v' value");
    });

    it("Should revert when passing an invalid nonce", async () => {
      const { v, r, s } = getApprovalForAllSignedData(
        parseInt((await collateralToken.nonces(deployer.address)).toString()),
        deployer,
        secondAccount.address,
        true,
        futureTimestamp,
        collateralToken.address
      );

      await expect(
        collateralToken
          .connect(secondAccount)
          .metaSetApprovalForAll(
            deployer.address,
            secondAccount.address,
            true,
            nonce + 5,
            futureTimestamp,
            v,
            r,
            s
          )
      ).to.be.revertedWith("CollateralToken: invalid nonce");
    });

    it("Should be able to set approvals through meta transactions", async () => {
      expect(
        await collateralToken.isApprovedForAll(
          deployer.address,
          secondAccount.address
        )
      ).to.equal(false);

      const { v, r, s } = getApprovalForAllSignedData(
        parseInt((await collateralToken.nonces(deployer.address)).toString()),
        deployer,
        secondAccount.address,
        true,
        futureTimestamp,
        collateralToken.address
      );

      await expect(
        collateralToken
          .connect(secondAccount)
          .metaSetApprovalForAll(
            deployer.address,
            secondAccount.address,
            true,
            nonce,
            futureTimestamp,
            v,
            r,
            s
          )
      )
        .to.emit(collateralToken, "ApprovalForAll")
        .withArgs(deployer.address, secondAccount.address, true);

      expect(
        await collateralToken.isApprovedForAll(
          deployer.address,
          secondAccount.address
        )
      ).to.equal(true);
    });
  });

  describe("createCollateralToken", () => {
    it("Should be able to create a new CollateralToken", async () => {
      // Create a new CollateralToken
      await createCollateralToken(
        deployer,
        qToken,
        ethers.constants.AddressZero
      );

      const collateralTokenId = await collateralToken.getCollateralTokenId(
        qToken.address,
        ethers.constants.AddressZero
      );

      // Should have a non-zero token id for the first CollateralToken
      expect(collateralTokenId).to.not.be.equal(ethers.BigNumber.from("0"));

      // CollateralToken info should match what was passed when creating the token
      const collateralTokenInfo = await collateralToken.idToInfo(
        collateralTokenId
      );

      expect(collateralTokenInfo.qTokenAddress).to.equal(qToken.address);
      expect(collateralTokenInfo.qTokenAsCollateral).to.equal(
        ethers.constants.AddressZero
      );
    });

    it("Should revert when an unauthorized account tries to create a new CollateralToken", async () => {
      await expect(
        createCollateralToken(
          secondAccount,
          qToken,
          ethers.constants.AddressZero
        )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should revert when trying to create a collateral token with the qToken and qTokenAsCollateral being equal", async () => {
      await expect(
        createCollateralToken(deployer, qToken, qToken.address)
      ).to.be.revertedWith(
        "CollateralToken: Can only create a collateral token with different tokens"
      );
    });

    it("Should emit the CollateralTokenCreated event", async () => {
      const qTokenAsCollateral = ethers.Wallet.createRandom().address;

      await expect(
        await collateralToken
          .connect(deployer)
          .createSpreadCollateralToken(qToken.address, qTokenAsCollateral)
      )
        .to.emit(collateralToken, "CollateralTokenCreated")
        .withArgs(
          qToken.address,
          qTokenAsCollateral,
          await collateralToken.getCollateralTokenId(
            qToken.address,
            qTokenAsCollateral
          )
        );
    });
  });

  describe("mintCollateralToken", () => {
    it("Admin should be able to mint CollateralTokens", async () => {
      await createCollateralToken(
        deployer,
        qToken,
        ethers.constants.AddressZero
      );

      const collateralTokenId = await collateralToken.getCollateralTokenId(
        qToken.address,
        ethers.constants.AddressZero
      );

      // Initial balance should be 0
      expect(
        await collateralToken.balanceOf(userAddress, collateralTokenId)
      ).to.equal(ethers.BigNumber.from("0"));

      // Mint some of the CollateralToken
      await collateralToken
        .connect(deployer)
        .mintCollateralToken(
          userAddress,
          collateralTokenId,
          ethers.BigNumber.from("10")
        );

      // User's balance should have increased
      expect(
        await collateralToken.balanceOf(userAddress, collateralTokenId)
      ).to.equal(ethers.BigNumber.from("10"));
    });

    it("Should revert when an unauthorized account tries to mint CollateralTokens", async () => {
      await createCollateralToken(
        deployer,
        qToken,
        ethers.constants.AddressZero
      );

      const collateralTokenId = await collateralToken.getCollateralTokenId(
        qToken.address,
        ethers.constants.AddressZero
      );

      await expect(
        collateralToken
          .connect(secondAccount)
          .mintCollateralToken(
            userAddress,
            collateralTokenId,
            ethers.BigNumber.from("1000")
          )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should emit the TransferSingle event with the `from` parameter being the zero address", async () => {
      await createCollateralToken(
        deployer,
        qToken,
        ethers.constants.AddressZero
      );

      const collateralTokenId = await collateralToken.getCollateralTokenId(
        qToken.address,
        ethers.constants.AddressZero
      );

      await expect(
        await collateralToken
          .connect(deployer)
          .mintCollateralToken(
            userAddress,
            collateralTokenId,
            ethers.BigNumber.from("10")
          )
      )
        .to.emit(collateralToken, "TransferSingle")
        .withArgs(
          deployer.address,
          ethers.constants.AddressZero,
          userAddress,
          collateralTokenId,
          ethers.BigNumber.from("10")
        );
    });
  });

  describe("burnCollateralToken", () => {
    it("Admin should be able to burn CollateralTokens", async () => {
      await createCollateralToken(
        deployer,
        qToken,
        ethers.constants.AddressZero
      );

      const collateralTokenId = await collateralToken.getCollateralTokenId(
        qToken.address,
        ethers.constants.AddressZero
      );

      await collateralToken
        .connect(deployer)
        .mintCollateralToken(
          userAddress,
          collateralTokenId,
          ethers.BigNumber.from("10")
        );

      const balanceAfterMint = parseInt(
        (
          await collateralToken.balanceOf(userAddress, collateralTokenId)
        ).toString()
      );

      // Burn some of the CollateralToken from the user
      await collateralToken
        .connect(deployer)
        .burnCollateralToken(
          userAddress,
          collateralTokenId,
          ethers.BigNumber.from("5")
        );

      expect(
        parseInt(
          (
            await collateralToken.balanceOf(userAddress, collateralTokenId)
          ).toString()
        )
      ).to.be.lessThan(balanceAfterMint);
    });

    it("Should revert when an unauthorized account tries to burn CollateralTokens", async () => {
      await createCollateralToken(
        deployer,
        qToken,
        ethers.constants.AddressZero
      );

      const collateralTokenId = await collateralToken.getCollateralTokenId(
        qToken.address,
        ethers.constants.AddressZero
      );

      await collateralToken
        .connect(deployer)
        .mintCollateralToken(
          await secondAccount.getAddress(),
          collateralTokenId,
          ethers.BigNumber.from("10")
        );

      await expect(
        collateralToken
          .connect(secondAccount)
          .burnCollateralToken(
            await secondAccount.getAddress(),
            collateralTokenId,
            ethers.BigNumber.from("10")
          )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should emit the TransferSingle event with the `to` parameter being the zero address", async () => {
      await createCollateralToken(
        deployer,
        qToken,
        ethers.constants.AddressZero
      );

      const collateralTokenId = await collateralToken.getCollateralTokenId(
        qToken.address,
        ethers.constants.AddressZero
      );

      await collateralToken
        .connect(deployer)
        .mintCollateralToken(
          userAddress,
          collateralTokenId,
          ethers.BigNumber.from("10")
        );

      await expect(
        collateralToken
          .connect(deployer)
          .burnCollateralToken(
            userAddress,
            collateralTokenId,
            ethers.BigNumber.from("5")
          )
      )
        .to.emit(collateralToken, "TransferSingle")
        .withArgs(
          deployer.address,
          userAddress,
          ethers.constants.AddressZero,
          collateralTokenId,
          ethers.BigNumber.from("5")
        );
    });
  });
});
