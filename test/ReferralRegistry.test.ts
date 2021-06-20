import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { expect } from "chai";
import { formatBytes32String } from "ethers/lib/utils";
import { ethers, waffle } from "hardhat";
import ReferralRegistryJSON from "../artifacts/contracts/periphery/ReferralRegistry.sol/ReferralRegistry.json";
import { ReferralRegistry } from "../typechain";

const { deployContract } = waffle;

describe("Referral Registry", () => {
  let deployer: SignerWithAddress;
  let signer: SignerWithAddress;
  let signerTwo: SignerWithAddress;
  let defaultReferrer: SignerWithAddress;
  let referralRegistry: ReferralRegistry;

  const dummyCode = formatBytes32String("test");
  const dummyCode1 = formatBytes32String("test1");
  const dummyCode2 = formatBytes32String("test2");
  const dummyCode3 = formatBytes32String("test3");

  before(async function () {
    [deployer, signer, signerTwo, defaultReferrer] = await ethers.getSigners();
  });

  describe("ReferralRegistry", () => {
    beforeEach(async function () {
      referralRegistry = (await deployContract(deployer, ReferralRegistryJSON, [
        await defaultReferrer.getAddress(),
        3,
      ])) as ReferralRegistry;
    });

    it("should create a referral and emit an event for its creator", async () => {
      await expect(
        referralRegistry.connect(signer).claimReferralCode(dummyCode)
      )
        .to.emit(referralRegistry, "CreatedReferralCode")
        .withArgs(await signer.getAddress(), dummyCode);
      expect(await referralRegistry.codeOwner(dummyCode)).to.be.equal(
        await signer.getAddress()
      );
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
        referralRegistry.connect(signer).registerUserByReferralCode(dummyCode)
      ).to.be.revertedWith("ReferralRegistry: cannot refer self");
    });

    // it("cannot register non-existing codes", async () => {
    //   await expect(
    //     referralRegistry.registerUserByReferralCode(formatBytes32String("lol"))
    //   ).to.be.revertedWith("ReferralRegistry: code does not exist");
    // });

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
        .registerUserByReferralCode(dummyCode);
      await expect(
        referralRegistry.connect(signer).registerUserByReferralCode(dummyCode)
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
        .registerUserByReferralCode(dummyCode);
      expect(
        await referralRegistry.getReferrer(await signerTwo.getAddress())
      ).to.be.equal(await signer.getAddress());
    });
  });
});