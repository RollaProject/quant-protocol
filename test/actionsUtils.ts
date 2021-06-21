import { BigNumberish, BytesLike, constants } from "ethers";
import { defaultAbiCoder } from "ethers/lib/utils";
import { ActionArgs } from "./testUtils";

const { Zero, AddressZero } = constants;

type MintOptionArgs = {
  to: string;
  qToken: string;
  amount: BigNumberish;
};
type MintSpreadArgs = {
  qTokenToMint: string;
  qTokenForCollateral: string;
  amount: BigNumberish;
};
type ExerciseArgs = { qToken: string; amount: BigNumberish };
type ClaimCollateralArgs = {
  collateralTokenId: BigNumberish;
  amount: BigNumberish;
};
type NeutralizeArgs = {
  collateralTokenId: BigNumberish;
  amount: BigNumberish;
};
type QTokenPermitArgs = {
  qToken: string;
  owner: string;
  spender: string;
  value: BigNumberish;
  deadline: BigNumberish;
  v: BigNumberish;
  r: BytesLike;
  s: BytesLike;
};
type CollateralTokenApprovalArgs = {
  owner: string;
  operator: string;
  approved: boolean;
  nonce: BigNumberish;
  deadline: BigNumberish;
  v: BigNumberish;
  r: BytesLike;
  s: BytesLike;
};
type CallArgs = { callee: string; data: BytesLike };

export const encodeMintOptionArgs = (args: MintOptionArgs): ActionArgs => {
  return {
    actionType: "MINT_OPTION",
    qToken: args.qToken,
    secondaryAddress: AddressZero,
    receiver: args.to,
    amount: args.amount,
    collateralTokenId: Zero.toString(),
    data: "0x",
  };
};

export const encodeMintSpreadArgs = (args: MintSpreadArgs): ActionArgs => {
  return {
    actionType: "MINT_SPREAD",
    qToken: args.qTokenToMint,
    secondaryAddress: args.qTokenForCollateral,
    receiver: AddressZero,
    amount: args.amount,
    collateralTokenId: Zero.toString(),
    data: "0x",
  };
};

export const encodeExerciseArgs = (args: ExerciseArgs): ActionArgs => {
  return {
    actionType: "EXERCISE",
    qToken: args.qToken,
    secondaryAddress: AddressZero,
    receiver: AddressZero,
    amount: args.amount,
    collateralTokenId: Zero.toString(),
    data: "0x",
  };
};

export const encodeClaimCollateralArgs = (
  args: ClaimCollateralArgs
): ActionArgs => {
  return {
    actionType: "CLAIM_COLLATERAL",
    qToken: AddressZero,
    secondaryAddress: AddressZero,
    receiver: AddressZero,
    amount: args.amount,
    collateralTokenId: args.collateralTokenId,
    data: "0x",
  };
};

export const encodeNeutralizeArgs = (args: NeutralizeArgs): ActionArgs => {
  return {
    actionType: "NEUTRALIZE",
    qToken: AddressZero,
    secondaryAddress: AddressZero,
    receiver: AddressZero,
    amount: args.amount,
    collateralTokenId: args.collateralTokenId,
    data: "0x",
  };
};

export const encodeQTokenPermitArgs = (args: QTokenPermitArgs): ActionArgs => {
  return {
    actionType: "QTOKEN_PERMIT",
    qToken: args.qToken,
    secondaryAddress: args.owner,
    receiver: args.spender,
    amount: args.value,
    collateralTokenId: args.deadline,
    data: defaultAbiCoder.encode(
      ["uint8", "bytes32", "bytes32"],
      [args.v, args.r, args.s]
    ),
  };
};

export const encodeCollateralTokenApprovalArgs = (
  args: CollateralTokenApprovalArgs
): ActionArgs => {
  return {
    actionType: "COLLATERAL_TOKEN_APPROVAL",
    qToken: AddressZero,
    secondaryAddress: args.owner,
    receiver: args.operator,
    amount: args.nonce,
    collateralTokenId: args.deadline,
    data: defaultAbiCoder.encode(
      ["bool", "uint8", "bytes32", "bytes32"],
      [args.approved, args.v, args.r, args.s]
    ),
  };
};

export const encodeCallArgs = (args: CallArgs): ActionArgs => {
  return {
    actionType: "CALL",
    qToken: AddressZero,
    secondaryAddress: AddressZero,
    receiver: args.callee,
    amount: Zero.toString(),
    collateralTokenId: Zero.toString(),
    data: args.data,
  };
};
