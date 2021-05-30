export const domainType = [
  {
    name: "name",
    type: "string",
  },
  {
    name: "version",
    type: "string",
  },
  {
    name: "chainId",
    type: "uint256",
  },
  {
    name: "verifyingContract",
    type: "address",
  },
];

export const metaActionType = [
  { name: "nonce", type: "uint256" },
  { name: "from", type: "address" },
  { name: "actions", type: "ActionArgs[]" },
];

export const actionType = [
  { name: "actionType", type: "string" },
  { name: "qToken", type: "address" },
  { name: "qTokenSecondary", type: "address" },
  { name: "receiver", type: "address" },
  { name: "amount", type: "uint256" },
  { name: "collateralTokenId", type: "uint256" },
  { name: "data", type: "bytes" },
];