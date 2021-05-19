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
  let timelockController: Signer;
  let secondAccount: Signer;
  let assetRegistryManager: Signer;
  let collateralCreator: Signer;
  let collateralMinter: Signer;
  let collateralBurner: Signer;
  let userAddress: string;
  let WETH: MockERC20;
  let USDC: MockERC20;

  const createCollateralToken = async (
    account: Signer,
    qToken: QToken,
    qTokenAsCollateral: string
  ) => {
    await collateralToken
      .connect(account)
      .createCollateralToken(qToken.address, qTokenAsCollateral);
  };

  const createTwoCollateralTokens = async (): Promise<Array<BigNumber>> => {
    await createCollateralToken(
      collateralCreator,
      qToken,
      ethers.constants.AddressZero
    );
    const firstCollateralTokenId = await collateralToken.collateralTokensIds(
      ethers.BigNumber.from("0")
    );

    const secondQToken = await deployQToken(
      timelockController,
      quantConfig,
      WETH.address,
      USDC.address,
      ethers.constants.AddressZero,
      ethers.utils.parseUnits("2000", await USDC.decimals()),
      ethers.BigNumber.from("1618592400"),
      true
    );
    await createCollateralToken(
      collateralCreator,
      secondQToken,
      ethers.constants.AddressZero
    );
    const secondCollateralTokenId = await collateralToken.collateralTokensIds(
      ethers.BigNumber.from("1")
    );

    return [firstCollateralTokenId, secondCollateralTokenId];
  };

  beforeEach(async () => {
    [
      timelockController,
      secondAccount,
      assetRegistryManager,
      collateralCreator,
      collateralMinter,
      collateralBurner,
    ] = await provider.getWallets();
    userAddress = await secondAccount.getAddress();

    quantConfig = await deployQuantConfig(timelockController, [
      {
        addresses: [await assetRegistryManager.getAddress()],
        role: "ASSETS_REGISTRY_MANAGER_ROLE",
      },
      {
        addresses: [await collateralCreator.getAddress()],
        role: "COLLATERAL_CREATOR_ROLE",
      },
      {
        addresses: [await collateralMinter.getAddress()],
        role: "COLLATERAL_MINTER_ROLE",
      },
      {
        addresses: [await collateralBurner.getAddress()],
        role: "COLLATERAL_BURNER_ROLE",
      },
    ]);

    WETH = await mockERC20(timelockController, "WETH");
    USDC = await mockERC20(timelockController, "USDC");

    const assetsRegistry = await deployAssetsRegistry(
      timelockController,
      quantConfig
    );

    await assetsRegistry
      .connect(assetRegistryManager)
      .addAsset(WETH.address, "", "", 0, 1000);
    await assetsRegistry
      .connect(assetRegistryManager)
      .addAsset(USDC.address, "", "", 0, 1000);

    qToken = await deployQToken(
      timelockController,
      quantConfig,
      WETH.address,
      USDC.address
    );

    collateralToken = await deployCollateralToken(
      timelockController,
      quantConfig
    );
  });

  describe("createCollateralToken", () => {
    it("Should be able to create a new CollateralToken", async () => {
      const firstIndex = ethers.BigNumber.from("0");

      // No CollateralToken has been created yet
      await expect(collateralToken.collateralTokensIds(firstIndex)).to.be
        .reverted;

      // Create a new CollateralToken
      await createCollateralToken(
        collateralCreator,
        qToken,
        ethers.constants.AddressZero
      );

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
      ).to.be.revertedWith(
        "CollateralToken: Only a collateral creator can create new CollateralTokens"
      );
    });

    it("Should revert when trying to create a duplicate CollateralToken", async () => {
      await createCollateralToken(
        collateralCreator,
        qToken,
        ethers.constants.AddressZero
      );

      await expect(
        createCollateralToken(
          collateralCreator,
          qToken,
          ethers.constants.AddressZero
        )
      ).to.be.revertedWith(
        "CollateralToken: this token has already been created"
      );
    });

    it("Should emit the CollateralTokenCreated event", async () => {
      await expect(
        await collateralToken
          .connect(collateralCreator)
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
      await createCollateralToken(
        collateralCreator,
        qToken,
        ethers.constants.AddressZero
      );

      const collateralTokenId = await collateralToken.collateralTokensIds(
        ethers.BigNumber.from("0")
      );

      // Initial balance should be 0
      expect(
        await collateralToken.balanceOf(userAddress, collateralTokenId)
      ).to.equal(ethers.BigNumber.from("0"));

      // Mint some of the CollateralToken
      await collateralToken
        .connect(collateralMinter)
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
        collateralCreator,
        qToken,
        ethers.constants.AddressZero
      );

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
        "CollateralToken: Only a collateral minter can mint CollateralTokens"
      );
    });

    it("Should emit the CollateralTokenMinted event", async () => {
      await createCollateralToken(
        collateralCreator,
        qToken,
        ethers.constants.AddressZero
      );

      const collateralTokenId = await collateralToken.collateralTokensIds(
        ethers.BigNumber.from("0")
      );

      await expect(
        await collateralToken
          .connect(collateralMinter)
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
      await createCollateralToken(
        collateralCreator,
        qToken,
        ethers.constants.AddressZero
      );

      const collateralTokenId = await collateralToken.collateralTokensIds(
        ethers.BigNumber.from("0")
      );

      await collateralToken
        .connect(collateralMinter)
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
        .connect(collateralBurner)
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
      await createCollateralToken(
        collateralCreator,
        qToken,
        ethers.constants.AddressZero
      );

      const collateralTokenId = await collateralToken.collateralTokensIds(
        ethers.BigNumber.from("0")
      );

      await collateralToken
        .connect(collateralMinter)
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
      ).to.be.revertedWith(
        "CollateralToken: Only a collateral burner can burn CollateralTokens"
      );
    });

    it("Should emit the CollateralTokenBurned event", async () => {
      await createCollateralToken(
        collateralCreator,
        qToken,
        ethers.constants.AddressZero
      );

      const collateralTokenId = await collateralToken.collateralTokensIds(
        ethers.BigNumber.from("0")
      );

      await collateralToken
        .connect(collateralMinter)
        .mintCollateralToken(
          userAddress,
          collateralTokenId,
          ethers.BigNumber.from("10")
        );

      await expect(
        collateralToken
          .connect(collateralBurner)
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
      const [firstCollateralTokenId, secondCollateralTokenId] =
        await createTwoCollateralTokens();

      expect(firstCollateralTokenId).to.not.be.equal(secondCollateralTokenId);

      const firstCollateralTokenAmount = ethers.BigNumber.from("10");
      const secondCollateralTokenAmount = ethers.BigNumber.from("20");

      await collateralToken
        .connect(collateralMinter)
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
      const [firstCollateralTokenId, secondCollateralTokenId] =
        await createTwoCollateralTokens();

      await expect(
        collateralToken
          .connect(secondAccount)
          .mintCollateralTokenBatch(
            userAddress,
            [firstCollateralTokenId, secondCollateralTokenId],
            [ethers.BigNumber.from("1000"), ethers.BigNumber.from("2000")]
          )
      ).to.be.revertedWith(
        "CollateralToken: Only a collateral minter can mint CollateralTokens"
      );
    });

    it("Should emit the CollateralTokenMinted event", async () => {
      const [firstCollateralTokenId, secondCollateralTokenId] =
        await createTwoCollateralTokens();

      const firstCollateralTokenAmount = ethers.BigNumber.from("10");
      const secondCollateralTokenAmount = ethers.BigNumber.from("20");

      await expect(
        collateralToken
          .connect(collateralMinter)
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
      const [firstCollateralTokenId, secondCollateralTokenId] =
        await createTwoCollateralTokens();

      const firstCollateralTokenAmount = ethers.BigNumber.from("10");
      const secondCollateralTokenAmount = ethers.BigNumber.from("20");

      await collateralToken
        .connect(collateralMinter)
        .mintCollateralTokenBatch(
          userAddress,
          [firstCollateralTokenId, secondCollateralTokenId],
          [firstCollateralTokenAmount, secondCollateralTokenAmount]
        );

      const [firstPrevBalance, secondPrevBalance] =
        await collateralToken.balanceOfBatch(
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
        .connect(collateralBurner)
        .burnCollateralTokenBatch(
          userAddress,
          [firstCollateralTokenId, secondCollateralTokenId],
          [ethers.BigNumber.from("5"), ethers.BigNumber.from("10")]
        );

      const [firstNewBalance, secondNewBalance] =
        await collateralToken.balanceOfBatch(
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
      const [firstCollateralTokenId, secondCollateralTokenId] =
        await createTwoCollateralTokens();

      const firstCollateralTokenAmount = ethers.BigNumber.from("10");
      const secondCollateralTokenAmount = ethers.BigNumber.from("20");

      await collateralToken
        .connect(collateralMinter)
        .mintCollateralTokenBatch(
          userAddress,
          [firstCollateralTokenId, secondCollateralTokenId],
          [firstCollateralTokenAmount, secondCollateralTokenAmount]
        );

      await expect(
        collateralToken
          .connect(secondAccount)
          .burnCollateralTokenBatch(
            userAddress,
            [firstCollateralTokenId, secondCollateralTokenId],
            [firstCollateralTokenAmount, secondCollateralTokenAmount]
          )
      ).to.be.revertedWith(
        "CollateralToken: Only a collateral burner can burn CollateralTokens"
      );
    });

    it("Should emit the CollateralTokenBurned event", async () => {
      const [firstCollateralTokenId, secondCollateralTokenId] =
        await createTwoCollateralTokens();

      const firstCollateralTokenAmount = ethers.BigNumber.from("10");
      const secondCollateralTokenAmount = ethers.BigNumber.from("20");

      await collateralToken
        .connect(collateralMinter)
        .mintCollateralTokenBatch(
          userAddress,
          [firstCollateralTokenId, secondCollateralTokenId],
          [firstCollateralTokenAmount, secondCollateralTokenAmount]
        );

      await expect(
        collateralToken
          .connect(collateralBurner)
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
