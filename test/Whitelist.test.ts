import { Signer } from "ethers";
import { ethers } from "hardhat";
import { beforeEach, describe, it } from "mocha";
import { MockERC20, QuantConfig, Whitelist } from "../typechain";
import { expect, provider } from "./setup";
import { deployQuantConfig, deployWhitelist, mockERC20 } from "./testUtils";

describe("Whitelist", () => {
  let quantConfig: QuantConfig;
  let whitelist: Whitelist;
  let admin: Signer;
  let secondAccount: Signer;
  let WETH: MockERC20;
  let USDC: MockERC20;

  beforeEach(async () => {
    [admin, secondAccount] = await provider.getWallets();

    WETH = await mockERC20(admin, "WETH", "Wrapped Ether");
    USDC = await mockERC20(admin, "USDC", "USD Coin", 6);

    quantConfig = await deployQuantConfig(admin);

    whitelist = await deployWhitelist(admin, quantConfig);
  });

  describe("whitelistUnderlying", () => {
    it("Admin should be able to whitelist underlying assets", async () => {
      await whitelist
        .connect(admin)
        .whitelistUnderlying(WETH.address, await WETH.decimals());

      expect(
        await whitelist.whitelistedUnderlyingDecimals(WETH.address)
      ).to.equal(await WETH.decimals());
    });

    it("Should revert when an unauthorized account tries to whitelist an underlying asset", async () => {
      await expect(
        whitelist
          .connect(secondAccount)
          .whitelistUnderlying(USDC.address, await USDC.decimals())
      ).to.be.revertedWith(
        "Whitelist: only admins can whitelist underlying tokens"
      );
    });
  });

  describe("blacklistUnderlying", () => {
    it("Admin should be able to blacklist underlying assets", async () => {
      await whitelist
        .connect(admin)
        .whitelistUnderlying(WETH.address, await WETH.decimals());

      expect(
        await whitelist.whitelistedUnderlyingDecimals(WETH.address)
      ).to.equal(await WETH.decimals());

      await whitelist.connect(admin).blacklistUnderlying(WETH.address);

      expect(
        await whitelist.whitelistedUnderlyingDecimals(WETH.address)
      ).to.equal(ethers.BigNumber.from("0"));
    });

    it("Should revert when unauthorized accounts try to blacklist underlying tokens", async () => {
      await expect(
        whitelist.connect(secondAccount).blacklistUnderlying(WETH.address)
      ).to.be.revertedWith(
        "Whitelist: only admins can blacklist underlying tokens"
      );
    });
  });
});
