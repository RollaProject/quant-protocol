import { BigNumber, Signer } from "ethers";
import { ethers } from "hardhat";
import { beforeEach, describe, it } from "mocha";
import { CollateralToken } from "../typechain/CollateralToken";
import { MockERC20 } from "../typechain/MockERC20";
import { QToken } from "../typechain/QToken";
import { QuantConfig } from "../typechain/QuantConfig";
import { expect, provider } from "./setup";
import {
  deployAssetsRegistry,
  deployCollateralToken,
  deployQToken,
  deployQuantConfig,
  mockERC20,
} from "./testUtils";

describe("CollateralToken", () => {
  let quantConfig: QuantConfig;
  let collateralToken: CollateralToken;
  let qToken: QToken;
  let admin: Signer;
  let secondAccount: Signer;
  let userAddress: string;
  let WETH: MockERC20;
  let USDC: MockERC20;

  const createCollateralToken = async (
    account: Signer,
    qToken: QToken,
    collateralizedFrom: string
  ) => {
    await collateralToken
      .connect(account)
      .createCollateralToken(qToken.address, collateralizedFrom);
  };

  const createTwoCollateralTokens = async (): Promise<Array<BigNumber>> => {
    await createCollateralToken(admin, qToken, ethers.constants.AddressZero);
    const firstCollateralTokenId = await collateralToken.collateralTokensIds(
      ethers.BigNumber.from("0")
    );

    const secondQToken = await deployQToken(
      admin,
      quantConfig,
      WETH.address,
      USDC.address,
      ethers.constants.AddressZero,
      ethers.utils.parseUnits("2000", await USDC.decimals()),
      ethers.BigNumber.from("1618592400"),
      true
    );
    await createCollateralToken(
      admin,
      secondQToken,
      ethers.constants.AddressZero
    );
    const secondCollateralTokenId = await collateralToken.collateralTokensIds(
      ethers.BigNumber.from("1")
    );

    return [firstCollateralTokenId, secondCollateralTokenId];
  };

  beforeEach(async () => {
    [admin, secondAccount] = await provider.getWallets();
    userAddress = await secondAccount.getAddress();

    quantConfig = await deployQuantConfig(admin);

    WETH = await mockERC20(admin, "WETH");
    USDC = await mockERC20(admin, "USDC");

    const assetsRegistry = await deployAssetsRegistry(admin, quantConfig);

    await assetsRegistry.connect(admin).addAsset(WETH.address, "", "", 0);
    await assetsRegistry.connect(admin).addAsset(USDC.address, "", "", 0);

    qToken = await deployQToken(admin, quantConfig, WETH.address, USDC.address);

    collateralToken = await deployCollateralToken(admin, quantConfig);
  });

  describe("createCollateralToken", () => {
    it("Should be able to create a new CollateralToken", async () => {
      const firstIndex = ethers.BigNumber.from("0");

      // No CollateralToken has been created yet
      await expect(collateralToken.collateralTokensIds(firstIndex)).to.be
        .reverted;

      // Create a new CollateralToken
      await createCollateralToken(admin, qToken, ethers.constants.AddressZero);

      const collateralTokenId = await collateralToken.collateralTokensIds(
        firstIndex
      );

      // Should have a non-zero token id for the first CollateralToken
      expect(collateralTokenId).to.not.be.equal(ethers.BigNumber.from("0"));

      // CollateralToken info should match what was passed when creating the token
      const collateralTokenInfo = await collateralToken.idToInfo(
        collateralTokenId
      );

      expect(collateralTokenInfo.qTokenAddress).to.equal(qToken.address);
      expect(collateralTokenInfo.collateralizedFrom).to.equal(
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
      ).to.be.revertedWith(
        "CollateralToken: Only the OptionsFactory can create new CollateralTokens"
      );
    });

    it("Should revert when trying to create a duplicate CollateralToken", async () => {
      await createCollateralToken(admin, qToken, ethers.constants.AddressZero);

      await expect(
        createCollateralToken(admin, qToken, ethers.constants.AddressZero)
      ).to.be.revertedWith(
        "CollateralToken: this token has already been created"
      );
    });

    it("Should emit the CollateralTokenCreated event", async () => {
      await expect(
        await collateralToken
          .connect(admin)
          .createCollateralToken(qToken.address, ethers.constants.AddressZero)
      )
        .to.emit(collateralToken, "CollateralTokenCreated")
        .withArgs(
          qToken.address,
          ethers.constants.AddressZero,
          await collateralToken.collateralTokensIds(ethers.BigNumber.from("0")),
          "1"
        );
    });
  });

  describe("mintCollateralToken", () => {
    it("Admin should be able to mint CollateralTokens", async () => {
      await createCollateralToken(admin, qToken, ethers.constants.AddressZero);

      const collateralTokenId = await collateralToken.collateralTokensIds(
        ethers.BigNumber.from("0")
      );

      // Initial balance should be 0
      expect(
        await collateralToken.balanceOf(userAddress, collateralTokenId)
      ).to.equal(ethers.BigNumber.from("0"));

      // Mint some of the CollateralToken
      await collateralToken
        .connect(admin)
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
      await createCollateralToken(admin, qToken, ethers.constants.AddressZero);

      const collateralTokenId = await collateralToken.collateralTokensIds(
        ethers.BigNumber.from("0")
      );

      await expect(
        collateralToken
          .connect(secondAccount)
          .mintCollateralToken(
            userAddress,
            collateralTokenId,
            ethers.BigNumber.from("1000")
          )
      ).to.be.revertedWith(
        "CollateralToken: Only the OptionsFactory can mint CollateralTokens"
      );
    });

    it("Should emit the CollateralTokenMinted event", async () => {
      await createCollateralToken(admin, qToken, ethers.constants.AddressZero);

      const collateralTokenId = await collateralToken.collateralTokensIds(
        ethers.BigNumber.from("0")
      );

      await expect(
        await collateralToken
          .connect(admin)
          .mintCollateralToken(
            userAddress,
            collateralTokenId,
            ethers.BigNumber.from("10")
          )
      )
        .to.emit(collateralToken, "CollateralTokenMinted")
        .withArgs(userAddress, collateralTokenId, ethers.BigNumber.from("10"));
    });
  });

  describe("burnCollateralToken", () => {
    it("Admin should be able to burn CollateralTokens", async () => {
      await createCollateralToken(admin, qToken, ethers.constants.AddressZero);

      const collateralTokenId = await collateralToken.collateralTokensIds(
        ethers.BigNumber.from("0")
      );

      await collateralToken
        .connect(admin)
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
      const supplyAfterMint = parseInt(
        (await collateralToken.tokenSupplies(collateralTokenId)).toString()
      );

      // Burn some of the CollateralToken from the user
      await collateralToken
        .connect(admin)
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

      expect(
        parseInt(
          (await collateralToken.tokenSupplies(collateralTokenId)).toString()
        )
      ).to.be.lessThan(supplyAfterMint);
    });

    it("Should revert when an unauthorized account tries to burn CollateralTokens", async () => {
      await createCollateralToken(admin, qToken, ethers.constants.AddressZero);

      const collateralTokenId = await collateralToken.collateralTokensIds(
        ethers.BigNumber.from("0")
      );

      await collateralToken
        .connect(admin)
        .mintCollateralToken(
          await admin.getAddress(),
          collateralTokenId,
          ethers.BigNumber.from("10")
        );

      await expect(
        collateralToken
          .connect(secondAccount)
          .burnCollateralToken(
            await admin.getAddress(),
            collateralTokenId,
            ethers.BigNumber.from("10")
          )
      ).to.be.revertedWith(
        "CollateralToken: Only the OptionsFactory can burn CollateralTokens"
      );
    });

    it("Should emit the CollateralTokenBurned event", async () => {
      await createCollateralToken(admin, qToken, ethers.constants.AddressZero);

      const collateralTokenId = await collateralToken.collateralTokensIds(
        ethers.BigNumber.from("0")
      );

      await collateralToken
        .connect(admin)
        .mintCollateralToken(
          userAddress,
          collateralTokenId,
          ethers.BigNumber.from("10")
        );

      await expect(
        collateralToken
          .connect(admin)
          .burnCollateralToken(
            userAddress,
            collateralTokenId,
            ethers.BigNumber.from("5")
          )
      )
        .to.emit(collateralToken, "CollateralTokenBurned")
        .withArgs(userAddress, collateralTokenId, ethers.BigNumber.from("5"));
    });
  });

  describe("mintCollateralTokenBatch", () => {
    it("Admin should be able to mint batches of CollateralTokens", async () => {
      const [
        firstCollateralTokenId,
        secondCollateralTokenId,
      ] = await createTwoCollateralTokens();

      expect(firstCollateralTokenId).to.not.be.equal(secondCollateralTokenId);

      const firstCollateralTokenAmount = ethers.BigNumber.from("10");
      const secondCollateralTokenAmount = ethers.BigNumber.from("20");

      await collateralToken
        .connect(admin)
        .mintCollateralTokenBatch(
          userAddress,
          [firstCollateralTokenId, secondCollateralTokenId],
          [firstCollateralTokenAmount, secondCollateralTokenAmount]
        );

      expect(
        await collateralToken.balanceOfBatch(
          [userAddress, userAddress],
          [firstCollateralTokenId, secondCollateralTokenId]
        )
      ).to.eql([firstCollateralTokenAmount, secondCollateralTokenAmount]);

      expect(
        await collateralToken.tokenSupplies(firstCollateralTokenId)
      ).to.equal(firstCollateralTokenAmount);

      expect(
        await collateralToken.tokenSupplies(secondCollateralTokenId)
      ).to.equal(secondCollateralTokenAmount);
    });

    it("Should revert when an unauthorized account tries to mint a batch of CollateralTokens", async () => {
      const [
        firstCollateralTokenId,
        secondCollateralTokenId,
      ] = await createTwoCollateralTokens();

      await expect(
        collateralToken
          .connect(secondAccount)
          .mintCollateralTokenBatch(
            userAddress,
            [firstCollateralTokenId, secondCollateralTokenId],
            [ethers.BigNumber.from("1000"), ethers.BigNumber.from("2000")]
          )
      ).to.be.revertedWith(
        "CollateralToken: Only the OptionsFactory can mint CollateralTokens"
      );
    });

    it("Should emit the CollateralTokenMinted event", async () => {
      const [
        firstCollateralTokenId,
        secondCollateralTokenId,
      ] = await createTwoCollateralTokens();

      const firstCollateralTokenAmount = ethers.BigNumber.from("10");
      const secondCollateralTokenAmount = ethers.BigNumber.from("20");

      await expect(
        collateralToken
          .connect(admin)
          .mintCollateralTokenBatch(
            userAddress,
            [firstCollateralTokenId, secondCollateralTokenId],
            [firstCollateralTokenAmount, secondCollateralTokenAmount]
          )
      )
        .to.emit(collateralToken, "CollateralTokenMinted")
        .withArgs(
          userAddress,
          secondCollateralTokenId,
          secondCollateralTokenAmount
        );
    });
  });

  describe("burnCollateralTokenBatch", () => {
    it("Admin should be able to burn batches of CollateralTokens", async () => {
      const [
        firstCollateralTokenId,
        secondCollateralTokenId,
      ] = await createTwoCollateralTokens();

      const firstCollateralTokenAmount = ethers.BigNumber.from("10");
      const secondCollateralTokenAmount = ethers.BigNumber.from("20");

      await collateralToken
        .connect(admin)
        .mintCollateralTokenBatch(
          userAddress,
          [firstCollateralTokenId, secondCollateralTokenId],
          [firstCollateralTokenAmount, secondCollateralTokenAmount]
        );

      const [
        firstPrevBalance,
        secondPrevBalance,
      ] = await collateralToken.balanceOfBatch(
        [userAddress, userAddress],
        [firstCollateralTokenId, secondCollateralTokenId]
      );

      const firstPrevSupply = await collateralToken.tokenSupplies(
        firstCollateralTokenId
      );
      const secondPrevSupply = await collateralToken.tokenSupplies(
        secondCollateralTokenId
      );

      await collateralToken
        .connect(admin)
        .burnCollateralTokenBatch(
          userAddress,
          [firstCollateralTokenId, secondCollateralTokenId],
          [ethers.BigNumber.from("5"), ethers.BigNumber.from("10")]
        );

      const [
        firstNewBalance,
        secondNewBalance,
      ] = await collateralToken.balanceOfBatch(
        [userAddress, userAddress],
        [firstCollateralTokenId, secondCollateralTokenId]
      );

      const firstNewSupply = await collateralToken.tokenSupplies(
        firstCollateralTokenId
      );
      const secondNewSupply = await collateralToken.tokenSupplies(
        secondCollateralTokenId
      );

      expect(parseInt(firstPrevBalance.toString())).to.be.greaterThan(
        parseInt(firstNewBalance.toString())
      );
      expect(parseInt(secondPrevBalance.toString())).to.be.greaterThan(
        parseInt(secondNewBalance.toString())
      );

      expect(parseInt(firstPrevSupply.toString())).to.be.greaterThan(
        parseInt(firstNewSupply.toString())
      );
      expect(parseInt(secondPrevSupply.toString())).to.be.greaterThan(
        parseInt(secondNewSupply.toString())
      );
    });

    it("Should revert when an unauthorized account tries to burn a batch of CollateralTokens", async () => {
      const [
        firstCollateralTokenId,
        secondCollateralTokenId,
      ] = await createTwoCollateralTokens();

      const firstCollateralTokenAmount = ethers.BigNumber.from("10");
      const secondCollateralTokenAmount = ethers.BigNumber.from("20");

      const adminAddress = await admin.getAddress();

      await collateralToken
        .connect(admin)
        .mintCollateralTokenBatch(
          adminAddress,
          [firstCollateralTokenId, secondCollateralTokenId],
          [firstCollateralTokenAmount, secondCollateralTokenAmount]
        );

      await expect(
        collateralToken
          .connect(secondAccount)
          .burnCollateralTokenBatch(
            adminAddress,
            [firstCollateralTokenId, secondCollateralTokenId],
            [firstCollateralTokenAmount, secondCollateralTokenAmount]
          )
      ).to.be.revertedWith(
        "CollateralToken: Only the OptionsFactory can burn CollateralTokens"
      );
    });

    it("Should emit the CollateralTokenBurned event", async () => {
      const [
        firstCollateralTokenId,
        secondCollateralTokenId,
      ] = await createTwoCollateralTokens();

      const firstCollateralTokenAmount = ethers.BigNumber.from("10");
      const secondCollateralTokenAmount = ethers.BigNumber.from("20");

      await collateralToken
        .connect(admin)
        .mintCollateralTokenBatch(
          userAddress,
          [firstCollateralTokenId, secondCollateralTokenId],
          [firstCollateralTokenAmount, secondCollateralTokenAmount]
        );

      await expect(
        collateralToken
          .connect(admin)
          .burnCollateralTokenBatch(
            userAddress,
            [firstCollateralTokenId, secondCollateralTokenId],
            [ethers.BigNumber.from("5"), ethers.BigNumber.from("10")]
          )
      )
        .to.emit(collateralToken, "CollateralTokenBurned")
        .withArgs(
          userAddress,
          secondCollateralTokenId,
          ethers.BigNumber.from("10")
        );
    });
  });
});
