import { expect } from "chai";
import { ethers } from "hardhat";
import { ActionsTester } from "../typechain";
import {
  encodeCollateralTokenApprovalArgs,
  encodeQTokenPermitArgs,
} from "./actionsUtils";
import { ActionType } from "./testUtils";
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
    it("Should revert when passing 0 as the amount", async () => {
      await expect(
        lib.parseMintOptionArgsTest({
          actionType: ActionType.MintOption,
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: AddressZero,
          amount: 0,
          secondaryUint: 0,
          data: "0x",
        })
      ).to.be.revertedWith("Actions: cannot mint 0 options");
    });

    it("Should parse valid parameters correctly", async () => {
      expect(
        await lib.parseMintOptionArgsTest({
          actionType: ActionType.MintOption,
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: AddressZero,
          amount,
          secondaryUint: 0,
          data: "0x",
        })
      ).to.be.deep.equal([AddressZero, AddressZero, amount]);
    });
  });

  describe("Test parseMintSpreadArgs", () => {
    it("Should revert when passing 0 as the amount", async () => {
      await expect(
        lib.parseMintSpreadArgsTest({
          actionType: ActionType.MintSpread,
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: AddressZero,
          amount: 0,
          secondaryUint: 0,
          data: "0x",
        })
      ).to.be.revertedWith("Actions: cannot mint 0 options from spreads");
    });

    it("Should parse valid parameters correctly", async () => {
      expect(
        await lib.parseMintSpreadArgsTest({
          actionType: ActionType.MintSpread,
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: AddressZero,
          amount,
          secondaryUint: 0,
          data: "0x",
        })
      ).to.be.deep.equal([AddressZero, AddressZero, amount]);
    });
  });

  describe("Test parseExerciseArgs", () => {
    it("Should parse valid parameters correctly", async () => {
      expect(
        await lib.parseExerciseArgsTest({
          actionType: ActionType.Exercise,
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: AddressZero,
          amount,
          secondaryUint: 0,
          data: "0x",
        })
      ).to.be.deep.equal([AddressZero, amount]);
    });
  });

  describe("Test parseClaimCollateralArgs", () => {
    it("Should parse valid parameters correctly", async () => {
      expect(
        await lib.parseClaimCollateralArgsTest({
          actionType: ActionType.ClaimCollateral,
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: AddressZero,
          amount,
          secondaryUint: 0,
          data: "0x",
        })
      ).to.be.deep.equal([Zero, amount]);
    });
  });

  describe("Test parseNeutralizeArgs", () => {
    it("Should parse valid parameters correctly", async () => {
      expect(
        await lib.parseNeutralizeArgsTest({
          actionType: ActionType.Neutralize,
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: AddressZero,
          amount,
          secondaryUint: 0,
          data: "0x",
        })
      ).to.be.deep.equal([Zero, amount]);
    });
  });

  describe("Test parseQTokenPermitArgs", () => {
    it("Should parse valid parameters correctly", async () => {
      expect(
        await lib.parseQTokenPermitArgsTest(
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
    it("Should parse valid parameters correctly", async () => {
      expect(
        await lib.parseCollateralTokenApprovalArgsTest(
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
    it("Should parse valid parameters correctly", async () => {
      const callee = ethers.Wallet.createRandom().address;
      const data = "0xd6cafe";
      expect(
        await lib.parseCallArgsTest({
          actionType: ActionType.Call,
          qToken: AddressZero,
          secondaryAddress: AddressZero,
          receiver: callee,
          amount: 0,
          secondaryUint: 0,
          data,
        })
      ).to.be.deep.equal([callee, data]);
    });
  });
});
