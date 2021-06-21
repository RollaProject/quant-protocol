import { expect } from "chai";
import { ethers } from "hardhat";
import { ActionsTester } from "../typechain";
import {
  encodeCollateralTokenApprovalArgs,
  encodeQTokenPermitArgs,
} from "./actionsUtils";
const { AddressZero, Zero, HashZero } = ethers.constants;

describe("Actions lib", () => {
  let lib: ActionsTester;
  const amount = ethers.BigNumber.from("10");

  before("setup contracts", async () => {
    const ActionsTesterArtifact = await ethers.getContractFactory(
      "ActionsTester"
    );
    lib = <ActionsTester>await ActionsTesterArtifact.deploy();
  });

  describe("Test parseMintOptionArgs", () => {
    it("Should revert when passing a wrong action type", async () => {
      await expect(
        lib.testParseMintOptionArgs({
          actionType: "SOME_ACTION",
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: AddressZero,
          amount,
          collateralTokenId: 0,
          data: "0x",
        })
      ).to.be.revertedWith(
        "Actions: can only parse arguments for the minting of options"
      );
    });

    it("Should revert when passing 0 as the amount", async () => {
      await expect(
        lib.testParseMintOptionArgs({
          actionType: "MINT_OPTION",
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: AddressZero,
          amount: 0,
          collateralTokenId: 0,
          data: "0x",
        })
      ).to.be.revertedWith("Actions: cannot mint 0 options");
    });

    it("Should parse valid parameters correctly", async () => {
      expect(
        await lib.testParseMintOptionArgs({
          actionType: "MINT_OPTION",
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: AddressZero,
          amount,
          collateralTokenId: 0,
          data: "0x",
        })
      ).to.be.deep.equal([AddressZero, AddressZero, amount]);
    });
  });

  describe("Test parseMintSpreadArgs", () => {
    it("Should revert when passing a wrong action type", async () => {
      await expect(
        lib.testParseMintSpreadArgs({
          actionType: "SOME_ACTION",
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: AddressZero,
          amount,
          collateralTokenId: 0,
          data: "0x",
        })
      ).to.be.revertedWith(
        "Actions: can only parse arguments for the minting of spreads"
      );
    });

    it("Should revert when passing 0 as the amount", async () => {
      await expect(
        lib.testParseMintSpreadArgs({
          actionType: "MINT_SPREAD",
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: AddressZero,
          amount: 0,
          collateralTokenId: 0,
          data: "0x",
        })
      ).to.be.revertedWith("Actions: cannot mint 0 options from spreads");
    });

    it("Should parse valid parameters correctly", async () => {
      expect(
        await lib.testParseMintSpreadArgs({
          actionType: "MINT_SPREAD",
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: AddressZero,
          amount,
          collateralTokenId: 0,
          data: "0x",
        })
      ).to.be.deep.equal([AddressZero, AddressZero, amount]);
    });
  });

  describe("Test parseExerciseArgs", () => {
    it("Should revert when passing a wrong action type", async () => {
      await expect(
        lib.testParseExerciseArgs({
          actionType: "SOME_ACTION",
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: AddressZero,
          amount,
          collateralTokenId: 0,
          data: "0x",
        })
      ).to.be.revertedWith("Actions: can only parse arguments for exercise");
    });

    it("Should parse valid parameters correctly", async () => {
      expect(
        await lib.testParseExerciseArgs({
          actionType: "EXERCISE",
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: AddressZero,
          amount,
          collateralTokenId: 0,
          data: "0x",
        })
      ).to.be.deep.equal([AddressZero, amount]);
    });
  });

  describe("Test parseClaimCollateralArgs", () => {
    it("Should revert when passing a wrong action type", async () => {
      await expect(
        lib.testParseClaimCollateralArgs({
          actionType: "SOME_ACTION",
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: AddressZero,
          amount,
          collateralTokenId: 0,
          data: "0x",
        })
      ).to.be.revertedWith(
        "Actions: can only parse arguments for claimCollateral"
      );
    });

    it("Should parse valid parameters correctly", async () => {
      expect(
        await lib.testParseClaimCollateralArgs({
          actionType: "CLAIM_COLLATERAL",
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: AddressZero,
          amount,
          collateralTokenId: 0,
          data: "0x",
        })
      ).to.be.deep.equal([Zero, amount]);
    });
  });

  describe("Test parseNeutralizeArgs", () => {
    it("Should revert when passing a wrong action type", async () => {
      await expect(
        lib.testParseNeutralizeArgs({
          actionType: "SOME_ACTION",
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: AddressZero,
          amount,
          collateralTokenId: 0,
          data: "0x",
        })
      ).to.be.revertedWith(
        "Actions: can only parse arguments for neutralizePosition"
      );
    });

    it("Should parse valid parameters correctly", async () => {
      expect(
        await lib.testParseNeutralizeArgs({
          actionType: "NEUTRALIZE",
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: AddressZero,
          amount,
          collateralTokenId: 0,
          data: "0x",
        })
      ).to.be.deep.equal([Zero, amount]);
    });
  });

  describe("Test parseQTokenPermitArgs", () => {
    it("Should revert when passing a wrong action type", async () => {
      await expect(
        lib.testParseQTokenPermitArgs({
          actionType: "SOME_ACTION",
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: AddressZero,
          amount,
          collateralTokenId: 0,
          data: "0x",
        })
      ).to.be.revertedWith(
        "Actions: can only parse arguments for QToken.permit"
      );
    });

    it("Should parse valid parameters correctly", async () => {
      expect(
        await lib.testParseQTokenPermitArgs(
          encodeQTokenPermitArgs({
            qToken: AddressZero,
            owner: AddressZero,
            spender: AddressZero,
            value: amount,
            deadline: Zero,
            v: Zero,
            r: HashZero,
            s: HashZero,
          })
        )
      ).to.be.deep.equal([
        AddressZero,
        AddressZero,
        AddressZero,
        amount,
        Zero,
        0,
        HashZero,
        HashZero,
      ]);
    });
  });

  describe("Test parseCollateralTokenApprovalArgs", () => {
    it("Should revert when passing a wrong action type", async () => {
      await expect(
        lib.testParseCollateralTokenApprovalArgs({
          actionType: "SOME_ACTION",
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: AddressZero,
          amount,
          collateralTokenId: 0,
          data: "0x",
        })
      ).to.be.revertedWith(
        "Actions: can only parse arguments for CollateralToken.metaSetApprovalForAll"
      );
    });

    it("Should parse valid parameters correctly", async () => {
      expect(
        await lib.testParseCollateralTokenApprovalArgs(
          encodeCollateralTokenApprovalArgs({
            owner: AddressZero,
            operator: AddressZero,
            approved: true,
            nonce: amount,
            deadline: Zero,
            v: Zero,
            r: HashZero,
            s: HashZero,
          })
        )
      ).to.be.deep.equal([
        AddressZero,
        AddressZero,
        true,
        amount,
        Zero,
        0,
        HashZero,
        HashZero,
      ]);
    });
  });

  describe("Test parseCallArgs", () => {
    it("Should revert when passing a wrong action type", async () => {
      await expect(
        lib.testParseCallArgs({
          actionType: "SOME_ACTION",
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: AddressZero,
          amount,
          collateralTokenId: 0,
          data: "0x",
        })
      ).to.be.revertedWith(
        "Actions: can only parse arguments for generic function calls"
      );
    });

    it("Should revert when passing the zero address as the receiver (callee)", async () => {
      await expect(
        lib.testParseCallArgs({
          actionType: "CALL",
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: AddressZero,
          amount,
          collateralTokenId: 0,
          data: "0x",
        })
      ).to.be.revertedWith("Actions: cannot make calls to the zero address");
    });

    it("Should parse valid parameters correctly", async () => {
      const callee = ethers.Wallet.createRandom().address;
      const data = "0xd6cafe";
      expect(
        await lib.testParseCallArgs({
          actionType: "CALL",
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: callee,
          amount: 0,
          collateralTokenId: 0,
          data,
        })
      ).to.be.deep.equal([callee, data]);
    });
  });
});
