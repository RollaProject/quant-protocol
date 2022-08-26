import * as sigUtil from "eth-sig-util";
import {
  BigNumber,
  BigNumberish,
  BytesLike,
  Contract,
  providers,
  Signer,
  Wallet,
} from "ethers";
import { ethers, waffle } from "hardhat";
import { hexToNumber } from "web3-utils";
import MockERC20JSON from "../artifacts/contracts/mocks/MockERC20.sol/MockERC20.json";
import AssetsRegistryJSON from "../artifacts/contracts/options/AssetsRegistry.sol/AssetsRegistry.json";
import CollateralTokenJSON from "../artifacts/contracts/options/CollateralToken.sol/CollateralToken.json";
import OptionsFactoryJSON from "../artifacts/contracts/options/OptionsFactory.sol/OptionsFactory.json";
import OracleRegistryJSON from "../artifacts/contracts/pricing/OracleRegistry.sol/OracleRegistry.json";
import QuantCalculatorJSON from "../artifacts/contracts/QuantCalculator.sol/QuantCalculator.json";
import {
  AssetsRegistry,
  OptionsFactory,
  OracleRegistry,
  QuantCalculator,
  SimpleOptionsFactory,
} from "../typechain";
import { CollateralToken } from "../typechain/CollateralToken";
import { MockERC20 } from "../typechain/MockERC20";
import { QToken } from "../typechain/QToken";
import {
  actionType,
  domainType,
  metaActionType,
  metaApprovalType,
} from "./eip712Types";
import { provider } from "./setup";

const { deployContract } = waffle;

const { keccak256, defaultAbiCoder, toUtf8Bytes, solidityPack } = ethers.utils;

const PERMIT_TYPEHASH = keccak256(
  toUtf8Bytes(
    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
  )
);

export const name = "Quant Protocol";
export const version = "0.6.2";
export const erc1155Uri = "https://tokens.rolla.finance/{id}.json";

const mockERC20 = async (
  deployer: Signer,
  tokenSymbol: string,
  tokenName?: string,
  decimals?: number
): Promise<MockERC20> => {
  return <MockERC20>(
    await deployContract(deployer, MockERC20JSON, [
      tokenName ?? "Mocked ERC20",
      tokenSymbol,
      decimals ?? 18,
    ])
  );
};

const deploySimpleOptionsFactory = async (
  assetsRegistry: string,
  strikeAsset: string,
  controller: string
): Promise<SimpleOptionsFactory> => {
  const SimpleOptionsFactory = await ethers.getContractFactory(
    "SimpleOptionsFactory"
  );
  const optionsFactory = <SimpleOptionsFactory>(
    await SimpleOptionsFactory.deploy(assetsRegistry, strikeAsset, controller)
  );

  return optionsFactory;
};

const deployQToken = async (
  deployer: Signer,
  underlyingAsset: string,
  strikeAsset: string,
  simpleOptionsFactory: SimpleOptionsFactory,
  assetsRegistry: string,
  oracle: string = ethers.Wallet.createRandom().address,
  expiryTime: BigNumber = ethers.BigNumber.from(
    Math.floor(Date.now() / 1000) + 30 * 24 * 3600
  ), // a month from the current time
  isCall = false,
  strikePrice = ethers.BigNumber.from("1400000000")
): Promise<QToken> => {
  const controller = await deployer.getAddress(); // will be the address with permission to mint and burn QTokens

  await simpleOptionsFactory.createOption(
    underlyingAsset,
    oracle,
    expiryTime,
    isCall,
    strikePrice
  );

  const [qTokenAddress] = await simpleOptionsFactory.getQToken(
    underlyingAsset,
    oracle,
    expiryTime,
    isCall,
    strikePrice
  );

  const QToken = await ethers.getContractFactory("QToken");

  const qToken = <QToken>QToken.attach(qTokenAddress);

  return qToken;
};

const deployCollateralToken = async (
  deployer: Signer
): Promise<CollateralToken> => {
  const erc1155Uri = "https://tokens.rolla.finance/{id}.json";
  const collateralToken = <CollateralToken>(
    await deployContract(deployer, CollateralTokenJSON, [
      name,
      version,
      erc1155Uri,
    ])
  );

  return collateralToken;
};

const deployOptionsFactory = async (
  deployer: Signer,
  strikeAsset: string,
  collateralToken: CollateralToken,
  controller: string,
  priceRegistry: string,
  assetsRegistry: string
): Promise<OptionsFactory> => {
  const optionsFactory = <OptionsFactory>(
    await deployContract(deployer, OptionsFactoryJSON, [
      strikeAsset,
      collateralToken.address,
      controller,
      priceRegistry,
      assetsRegistry,
    ])
  );

  return optionsFactory;
};

const deployAssetsRegistry = async (
  deployer: Signer
): Promise<AssetsRegistry> => {
  const assetsRegistry = <AssetsRegistry>(
    await deployContract(deployer, AssetsRegistryJSON)
  );

  return assetsRegistry;
};

const deployOracleRegistry = async (
  deployer: Signer
): Promise<OracleRegistry> => {
  const oracleRegistry = <OracleRegistry>(
    await deployContract(deployer, OracleRegistryJSON)
  );

  return oracleRegistry;
};

const getDomainSeparator = (name: string, tokenAddress: string): string => {
  return keccak256(
    defaultAbiCoder.encode(
      ["bytes32", "bytes32", "bytes32", "uint256", "address"],
      [
        keccak256(
          toUtf8Bytes(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
          )
        ),
        keccak256(toUtf8Bytes(name)),
        keccak256(toUtf8Bytes("1")),
        provider.network.chainId,
        tokenAddress,
      ]
    )
  );
};

const getApprovalDigest = async (
  token: Contract,
  approve: {
    owner: string;
    spender: string;
    value: BigNumber;
  },
  nonce: BigNumber,
  deadline: BigNumber
): Promise<string> => {
  const name = await token.name();
  const DOMAIN_SEPARATOR = getDomainSeparator(name, token.address);
  return keccak256(
    solidityPack(
      ["bytes1", "bytes1", "bytes32", "bytes32"],
      [
        "0x19",
        "0x01",
        DOMAIN_SEPARATOR,
        keccak256(
          defaultAbiCoder.encode(
            ["bytes32", "address", "address", "uint256", "uint256", "uint256"],
            [
              PERMIT_TYPEHASH,
              approve.owner,
              approve.spender,
              approve.value,
              nonce,
              deadline,
            ]
          )
        ),
      ]
    )
  );
};

type SignedTransactionData = {
  r: string;
  s: string;
  v: number;
};

const getSignedTransactionData = (
  nonce: number,
  deadline: number,
  userWallet: Wallet,
  actions: ActionArgs[],
  verifyingContract: string
): SignedTransactionData => {
  const message = {
    nonce,
    deadline,
    from: userWallet.address,
    actions,
  };

  const domainData = {
    name,
    version,
    verifyingContract,
    chainId: provider.network.chainId,
  };

  type MetaAction = "MetaAction";
  const metaAction: MetaAction = "MetaAction";

  const data = {
    types: {
      EIP712Domain: domainType,
      MetaAction: metaActionType,
      ActionArgs: actionType,
    },
    domain: domainData,
    primaryType: metaAction,
    message,
  };

  const signature = sigUtil.signTypedData_v4(
    Buffer.from(userWallet.privateKey.slice(2), "hex"),
    {
      data,
    }
  );

  const r = signature.slice(0, 66);
  const s = "0x".concat(signature.slice(66, 130));
  const vString = "0x".concat(signature.slice(130, 132));

  let v = hexToNumber(vString);
  if (![27, 28].includes(v)) v += 27;

  return {
    r,
    s,
    v,
  };
};

const getApprovalForAllSignedData = (
  nonce: number,
  ownerWallet: Wallet,
  operator: string,
  approved: boolean,
  deadline: number,
  verifyingContract: string
): SignedTransactionData => {
  const message = {
    cTokenOwner: ownerWallet.address,
    operator,
    approved,
    nonce,
    deadline,
  };

  const domainData = {
    name,
    version,
    verifyingContract,
    chainId: provider.network.chainId,
  };

  type metaSetApprovalForAll = "metaSetApprovalForAll";
  const metaSetApprovalForAll: metaSetApprovalForAll = "metaSetApprovalForAll";

  const data = {
    types: {
      EIP712Domain: domainType,
      metaSetApprovalForAll: metaApprovalType,
    },
    domain: domainData,
    primaryType: metaSetApprovalForAll,
    message,
  };

  const signature = sigUtil.signTypedData_v4(
    Buffer.from(ownerWallet.privateKey.slice(2), "hex"),
    {
      data,
    }
  );

  const r = signature.slice(0, 66);
  const s = "0x".concat(signature.slice(66, 130));
  const vString = "0x".concat(signature.slice(130, 132));

  let v = hexToNumber(vString);
  if (![27, 28].includes(v)) v += 27;

  return {
    r,
    s,
    v,
  };
};

const deployQuantCalculator = async (
  deployer: Signer,
  strikeAssetDecimals: number
): Promise<QuantCalculator> => {
  const quantCalculator = <QuantCalculator>(
    await deployContract(deployer, QuantCalculatorJSON, [strikeAssetDecimals])
  );
  return quantCalculator;
};

export enum ActionType {
  MintOption,
  MintSpread,
  Exercise,
  ClaimCollateral,
  Neutralize,
  QTokenPermit,
  CollateralTokenApproval,
  Call,
}

export enum PriceStatus {
  ACTIVE,
  AWAITING_SETTLEMENT_PRICE,
  SETTLED,
}

export type ActionArgs = {
  actionType: ActionType;
  qToken: string;
  secondaryAddress: string;
  receiver: string;
  amount: BigNumberish;
  secondaryUint: BigNumberish;
  data: BytesLike;
};

export const takeSnapshot = async (): Promise<string> => {
  const id: string = await provider.send("evm_snapshot", [
    new Date().getTime(),
  ]);

  return id;
};

export const revertToSnapshot = async (id: string): Promise<void> => {
  await provider.send("evm_revert", [id]);
};

export const getWalletFromMnemonic = (
  mnemonic: string,
  accountNumber = 0,
  provider?: providers.BaseProvider
): Wallet => {
  let wallet = ethers.Wallet.fromMnemonic(
    mnemonic,
    `m/44'/60'/0'/0/${accountNumber}`
  );

  if (provider) {
    wallet = wallet.connect(provider);
  }

  return wallet;
};

export const uintToBytes32 = (value: number): string => {
  return ethers.utils.hexZeroPad(
    ethers.BigNumber.from(value).toHexString(),
    32
  );
};

const toBytes32 = (bn: BigNumber): string => {
  return ethers.utils.hexlify(ethers.utils.zeroPad(bn.toHexString(), 32));
};

const setStorageAt = async (address: string, index: string, value: string) => {
  await provider.send("hardhat_setStorageAt", [address, index, value]);
  await provider.send("evm_mine", []); // Just mines to the next block
};

export const setQTokenBalance = async (
  qToken: string,
  user: string,
  amount: BigNumber
): Promise<void> => {
  const qTokenBalancesSlot = "0x1";

  const userBalanceSlot = ethers.utils.solidityKeccak256(
    ["uint256", "uint256"],
    [user, qTokenBalancesSlot]
  );

  await setStorageAt(qToken, userBalanceSlot, toBytes32(amount));

  // also need to increase the totalSupply
  const totalSupplySlot = "0x0";
  const totalSupply = BigNumber.from(
    await provider.getStorageAt(qToken, totalSupplySlot)
  );
  const newTotalSupply = totalSupply.add(amount);

  await setStorageAt(qToken, totalSupplySlot, toBytes32(newTotalSupply));
};

export const customError = (errorName: string, ...args: any[]): string => {
  let argumentString = "";

  if (Array.isArray(args) && args.length) {
    // add quotation marks to first argument if it is of string type
    if (typeof args[0] === "string") {
      args[0] = `"${args[0]}"`;
    }

    // add joining comma and quotation marks to all subsequent arguments, if they are of string type
    argumentString = args.reduce(function (acc: string, cur: any) {
      if (typeof cur === "string") return `${acc}, "${cur}"`;
      else return `${acc}, ${cur.toString()}`;
    });
  }

  return `'${errorName}(${argumentString})'`;
};

export {
  deployCollateralToken,
  deployOptionsFactory,
  deploySimpleOptionsFactory,
  deployQToken,
  deployAssetsRegistry,
  deployOracleRegistry,
  mockERC20,
  getApprovalDigest,
  getSignedTransactionData,
  deployQuantCalculator,
  getApprovalForAllSignedData,
};
