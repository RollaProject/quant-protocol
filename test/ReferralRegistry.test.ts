import { Wallet } from "ethers";
import { defaultAbiCoder, formatBytes32String } from "ethers/lib/utils";
import { ethers, waffle } from "hardhat";
import ReferralRegistryJSON from "../artifacts/contracts/periphery/ReferralRegistry.sol/ReferralRegistry.json";
import { ReferralRegistry } from "../typechain";
import { expect, provider } from "./setup";
import {
  getReferralActionSignedData,
  name,
  ReferralAction,
  version,
} from "./testUtils";

const { deployContract } = waffle;

const { HashZero } = ethers.constants;

describe("Referral Registry", () => {
  let deployer: Wallet;
  let signer: Wallet;
  let signerTwo: Wallet;
  let defaultReferrer: Wallet;
  let referralRegistry: ReferralRegistry;

  const dummyCode = "test";
  const dummyCode1 = "test1";
  const dummyCode2 = "test2";
  const dummyCode3 = "test3";

  before(async function () {
    [deployer, signer, signerTwo, defaultReferrer] =
      await provider.getWallets();
  });

  describe("ReferralRegistry", () => {
    beforeEach(async function () {
      referralRegistry = (await deployContract(deployer, ReferralRegistryJSON, [
        await defaultReferrer.getAddress(),
        3,
        name,
        version,
      ])) as ReferralRegistry;
    });

    it("should create a referral and emit an event for its creator", async () => {
      await expect(
        referralRegistry.connect(signer).claimReferralCode(dummyCode)
      )
        .to.emit(referralRegistry, "CreatedReferralCode")
        .withArgs(await signer.getAddress(), formatBytes32String(dummyCode));
      expect(
        await referralRegistry.codeOwner(formatBytes32String(dummyCode))
      ).to.be.equal(await signer.getAddress());
    });

    it("registers a user by a referer", async () => {
      await expect(
        referralRegistry
          .connect(signer)
          .registerUserByReferrer(await signerTwo.getAddress())
      )
        .to.emit(referralRegistry, "NewUserRegistration")
        .withArgs(
          await signer.getAddress(),
          await signerTwo.getAddress(),
          ethers.constants.HashZero
        );
      expect(
        await referralRegistry.userReferrer(await signer.getAddress())
      ).to.be.equal(await signerTwo.getAddress());
    });

    it("a user cannot claim more codes than allowed", async () => {
      await referralRegistry.connect(signer).claimReferralCode(dummyCode);
      await referralRegistry.connect(signer).claimReferralCode(dummyCode1);
      await referralRegistry.connect(signer).claimReferralCode(dummyCode2);
      await expect(
        referralRegistry.connect(signer).claimReferralCode(dummyCode3)
      ).to.be.revertedWith(
        "ReferralRegistry: user has claimed all their codes"
      );
    });

    it("cannot self refer", async () => {
      await referralRegistry.connect(signer).claimReferralCode(dummyCode);
      await expect(
        referralRegistry
          .connect(signer)
          .registerUserByReferralCode(formatBytes32String(dummyCode))
      ).to.be.revertedWith("ReferralRegistry: cannot refer self");
    });

    it("non-existing codes should register with the defaultReferrer", async () => {
      const code = formatBytes32String("badcode");
      await expect(
        referralRegistry.connect(signerTwo).registerUserByReferralCode(code)
      )
        .to.emit(referralRegistry, "NewUserRegistration")
        .withArgs(signerTwo.address, defaultReferrer.address, code);

      expect(await referralRegistry.userReferrer(signerTwo.address)).to.equal(
        defaultReferrer.address
      );
    });

    it("cannot use same code", async () => {
      await referralRegistry.connect(signer).claimReferralCode(dummyCode);
      await expect(
        referralRegistry.connect(signer).claimReferralCode(dummyCode)
      ).to.be.revertedWith("ReferralRegistry: code already exists");
    });

    it("cannot register twice", async () => {
      await referralRegistry.connect(signerTwo).claimReferralCode(dummyCode);
      await referralRegistry
        .connect(signer)
        .registerUserByReferralCode(formatBytes32String(dummyCode));
      await expect(
        referralRegistry
          .connect(signer)
          .registerUserByReferralCode(formatBytes32String(dummyCode))
      ).to.be.revertedWith("ReferralRegistry: cannot register twice");
    });

    it("by default referrals point to owner", async () => {
      expect(
        await referralRegistry
          .connect(signer)
          .getReferrer(await signerTwo.getAddress())
      ).to.be.equal(await referralRegistry.defaultReferrer());
    });

    it("refers a new user", async () => {
      await referralRegistry.connect(signer).claimReferralCode(dummyCode);
      await referralRegistry
        .connect(signerTwo)
        .registerUserByReferralCode(formatBytes32String(dummyCode));
      expect(
        await referralRegistry.getReferrer(await signerTwo.getAddress())
      ).to.be.equal(await signer.getAddress());
    });

    describe("metaReferralAction", () => {
      const futureTimestamp = Math.round(Date.now() / 1000) + 3600 * 24;
      let nonce: number;

      beforeEach(async () => {
        nonce = parseInt(
          (await referralRegistry.nonces(signer.address)).toString()
        );
      });

      it("should revert when passing an expired deadline", async () => {
        const pastTimestamp = Math.round(Date.now() / 1000) - 3600 * 24; // a day in the past

        await expect(
          referralRegistry
            .connect(signerTwo)
            .metaReferralAction(
              signer.address,
              ReferralAction.CLAIM_CODE,
              "0x",
              nonce,
              pastTimestamp,
              0,
              HashZero,
              HashZero
            )
        ).to.be.revertedWith("ReferralRegistry: expired deadline");
      });

      it("should revert when passing an invalid nonce", async () => {
        await expect(
          referralRegistry
            .connect(signerTwo)
            .metaReferralAction(
              signer.address,
              ReferralAction.CLAIM_CODE,
              "0x",
              nonce + 4,
              futureTimestamp,
              0,
              HashZero,
              HashZero
            )
        ).to.be.revertedWith("ReferralRegistry: invalid nonce");
      });

      it("should revert when passing an invalid signature", async () => {
        await expect(
          referralRegistry
            .connect(signerTwo)
            .metaReferralAction(
              signer.address,
              ReferralAction.CLAIM_CODE,
              "0x",
              nonce,
              futureTimestamp,
              0,
              HashZero,
              HashZero
            )
        ).to.be.revertedWith("ReferralRegistry: invalid signature");
      });

      it("should be able to claim referral codes through meta transactions", async () => {
        const code = "mycode";
        const actionData = defaultAbiCoder.encode(["string"], [code]);

        const { v, r, s } = getReferralActionSignedData(
          signer,
          ReferralAction.CLAIM_CODE,
          actionData,
          nonce,
          futureTimestamp,
          referralRegistry.address
        );

        await expect(
          referralRegistry
            .connect(signerTwo)
            .metaReferralAction(
              signer.address,
              ReferralAction.CLAIM_CODE,
              actionData,
              nonce,
              futureTimestamp,
              v,
              r,
              s
            )
        )
          .to.emit(referralRegistry, "CreatedReferralCode")
          .withArgs(await signer.getAddress(), formatBytes32String(code));
        expect(
          await referralRegistry.codeOwner(formatBytes32String(code))
        ).to.be.equal(await signer.getAddress());
      });

      it("should be able to register users by referral codes through meta transactions", async () => {
        const code = formatBytes32String("anothercode");
        const actionData = defaultAbiCoder.encode(["bytes32"], [code]);

        const { v, r, s } = getReferralActionSignedData(
          signer,
          ReferralAction.REGISTER_BY_CODE,
          actionData,
          nonce,
          futureTimestamp,
          referralRegistry.address
        );

        await expect(
          referralRegistry
            .connect(signerTwo)
            .metaReferralAction(
              signer.address,
              ReferralAction.REGISTER_BY_CODE,
              actionData,
              nonce,
              futureTimestamp,
              v,
              r,
              s
            )
        )
          .to.emit(referralRegistry, "NewUserRegistration")
          .withArgs(signer.address, defaultReferrer.address, code);

        expect(await referralRegistry.userReferrer(signer.address)).to.equal(
          defaultReferrer.address
        );
      });

      it("should be able to register users by referrer addresses through meta transactions", async () => {
        const referrer = deployer.address;
        const actionData = defaultAbiCoder.encode(["address"], [referrer]);

        const { v, r, s } = getReferralActionSignedData(
          signer,
          ReferralAction.REGISTER_BY_REFERRER,
          actionData,
          nonce,
          futureTimestamp,
          referralRegistry.address
        );

        await expect(
          referralRegistry
            .connect(signerTwo)
            .metaReferralAction(
              signer.address,
              ReferralAction.REGISTER_BY_REFERRER,
              actionData,
              nonce,
              futureTimestamp,
              v,
              r,
              s
            )
        )
          .to.emit(referralRegistry, "NewUserRegistration")
          .withArgs(
            await signer.getAddress(),
            await deployer.getAddress(),
            ethers.constants.HashZero
          );
        expect(
          await referralRegistry.userReferrer(await signer.getAddress())
        ).to.be.equal(await deployer.getAddress());
      });
    });
  });
});
