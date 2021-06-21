import { ethers } from "hardhat";
import { ReferralCodeValidatorTester } from "../typechain";
import { expect } from "./setup";

describe("ReferralCodeValidator lib", () => {
  let lib: ReferralCodeValidatorTester;

  before("setup contracts", async () => {
    const ReferralCodeValidatorTesterArtifact = await ethers.getContractFactory(
      "ReferralCodeValidatorTester"
    );
    lib = <ReferralCodeValidatorTester>(
      await ReferralCodeValidatorTesterArtifact.deploy()
    );
  });

  describe("Test validateCode", () => {
    it("Should revert with empty code", async () => {
      await expect(lib.testValidateCode("")).to.be.revertedWith(
        "string must be between 1 and 32 characters"
      );
    });

    it("Should revert with codes longer than 32 characters", async () => {
      const code = new Array(42).join("A");
      await expect(lib.testValidateCode(code)).to.be.revertedWith(
        "string must be between 1 and 32 characters"
      );
    });

    it("Should revert with codes starting with 0x", async () => {
      await expect(lib.testValidateCode("0xbadcode")).to.be.revertedWith(
        "string cannot start with 0x"
      );
    });

    it("Should revert with codes starting with 0X", async () => {
      await expect(lib.testValidateCode("0XBADCODE")).to.be.revertedWith(
        "string cannot start with 0X"
      );
    });

    it("Should convert uppercase to lower case", async () => {
      expect(await lib.testValidateCode("SOMECODE")).to.equal(
        ethers.utils.formatBytes32String("somecode")
      );
    });

    it("Should revert when there are invalid characters", async () => {
      await expect(lib.testValidateCode("1337h@x0r$")).to.be.revertedWith(
        "string contains invalid characters"
      );
    });

    it("Should return the same code when passing a valid, all lowercase one", async () => {
      const code = "someval1dc0de";
      expect(await lib.testValidateCode(code)).to.equal(
        ethers.utils.formatBytes32String(code)
      );
    });
  });
});
