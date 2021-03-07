import { BigNumber, Signer } from "ethers";
import { ethers, upgrades, waffle } from "hardhat";
import CollateralTokenJSON from "../artifacts/contracts/protocol/options/CollateralToken.sol/CollateralToken.json";
import OptionsFactoryJSON from "../artifacts/contracts/protocol/options/OptionsFactory.sol/OptionsFactory.json";
import QTokenJSON from "../artifacts/contracts/protocol/options/QToken.sol/QToken.json";
import WhitelistJSON from "../artifacts/contracts/protocol/options/Whitelist.sol/Whitelist.json";
import MockERC20JSON from "../artifacts/contracts/protocol/test/MockERC20.sol/MockERC20.json";
import { OptionsFactory, Whitelist } from "../typechain";
import { CollateralToken } from "../typechain/CollateralToken";
import { MockERC20 } from "../typechain/MockERC20";
import { QToken } from "../typechain/QToken";
import { QuantConfig } from "../typechain/QuantConfig";
import { provider } from "./setup";

const { deployContract, deployMockContract } = waffle;

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

const deployQuantConfig = async (admin: Signer): Promise<QuantConfig> => {
  const QuantConfig = await ethers.getContractFactory("QuantConfig");

  return <QuantConfig>(
    await upgrades.deployProxy(QuantConfig, [await admin.getAddress()])
  );
};

const deployQToken = async (
  deployer: Signer,
  quantConfig: QuantConfig,
  underlyingAsset: string,
  strikeAsset: string,
  oracle: string = ethers.constants.AddressZero,
  strikePrice = "1400",
  expiryTime: BigNumber = ethers.BigNumber.from(
    Math.floor(Date.now() / 1000) + 30 * 24 * 3600
  ), // a month from the current time
  isCall = false
): Promise<QToken> => {
  const ERC20ABI = (await ethers.getContractFactory("ERC20")).interface;
  const strike = <MockERC20>(
    new ethers.Contract(strikeAsset, ERC20ABI, provider)
  );
  const strikePriceBN = ethers.utils.parseUnits(
    strikePrice,
    await strike.decimals()
  );
  const qToken = <QToken>(
    await deployContract(deployer, QTokenJSON, [
      quantConfig.address,
      underlyingAsset,
      strikeAsset,
      oracle,
      strikePriceBN,
      expiryTime,
      isCall,
    ])
  );

  return qToken;
};

const deployCollateralToken = async (
  deployer: Signer,
  quantConfig: QuantConfig
): Promise<CollateralToken> => {
  const collateralToken = <CollateralToken>(
    await deployContract(deployer, CollateralTokenJSON, [quantConfig.address])
  );

  return collateralToken;
};

const deployOptionsFactory = async (
  deployer: Signer,
  quantConfig: QuantConfig,
  collateralToken: CollateralToken,
  whitelist: Whitelist
): Promise<OptionsFactory> => {
  const optionsFactory = <OptionsFactory>(
    await deployContract(deployer, OptionsFactoryJSON, [
      quantConfig.address,
      collateralToken.address,
      whitelist.address,
    ])
  );

  return optionsFactory;
};

const deployWhitelist = async (
  deployer: Signer,
  quantConfig: QuantConfig
): Promise<Whitelist> => {
  const whitelist = <Whitelist>(
    await deployContract(deployer, WhitelistJSON, [quantConfig.address])
  );

  return whitelist;
};

export {
  deployCollateralToken,
  deployOptionsFactory,
  deployQToken,
  deployQuantConfig,
  deployWhitelist,
  mockERC20,
};
