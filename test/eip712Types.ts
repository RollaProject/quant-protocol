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

export const metaTransactionType = [
  {
    name: "nonce",
    type: "uint256",
  },
  {
    name: "from",
    type: "address",
  },
  {
    name: "functionSignature",
    type: "bytes",
  },
];

export const actionType = [
  { name: "actionName", type: "string" },
  { name: "from", type: "address" },
  { name: "to", type: "address" },
  { name: "amount", type: "uint256" },
];

export const metaAction = [
  { name: "nonce", type: "uint256" },
  { name: "from", type: "address" },
  { name: "actions", type: "Action" },
];
