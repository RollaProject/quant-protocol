import { BigNumber, Signer } from "ethers";
import { ethers, upgrades, waffle } from "hardhat";
import AssetsRegistryJSON from "../artifacts/contracts/protocol/options/AssetsRegistry.sol/AssetsRegistry.json";
import CollateralTokenJSON from "../artifacts/contracts/protocol/options/CollateralToken.sol/CollateralToken.json";
import OptionsFactoryJSON from "../artifacts/contracts/protocol/options/OptionsFactory.sol/OptionsFactory.json";
import QTokenJSON from "../artifacts/contracts/protocol/options/QToken.sol/QToken.json";
import MockERC20JSON from "../artifacts/contracts/protocol/test/MockERC20.sol/MockERC20.json";
import { AssetsRegistry, OptionsFactory } from "../typechain";
import { CollateralToken } from "../typechain/CollateralToken";
import { MockERC20 } from "../typechain/MockERC20";
import { QToken } from "../typechain/QToken";
import { QuantConfig } from "../typechain/QuantConfig";

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
  strikePrice = ethers.BigNumber.from("1400000000"),
  expiryTime: BigNumber = ethers.BigNumber.from(
    Math.floor(Date.now() / 1000) + 30 * 24 * 3600
  ), // a month from the current time
  isCall = false
): Promise<QToken> => {
  const qToken = <QToken>(
    await deployContract(deployer, QTokenJSON, [
      quantConfig.address,
      underlyingAsset,
      strikeAsset,
      oracle,
      strikePrice,
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
  collateralToken: CollateralToken
): Promise<OptionsFactory> => {
  const optionsFactory = <OptionsFactory>(
    await deployContract(deployer, OptionsFactoryJSON, [
      quantConfig.address,
      collateralToken.address,
    ])
  );

  return optionsFactory;
};

const deployAssetsRegistry = async (
  deployer: Signer,
  quantConfig: QuantConfig
): Promise<AssetsRegistry> => {
  const assetsRegistry = <AssetsRegistry>(
    await deployContract(deployer, AssetsRegistryJSON, [quantConfig.address])
  );

  await quantConfig.connect(deployer).setAssetsRegistry(assetsRegistry.address);

  return assetsRegistry;
};

export {
  deployCollateralToken,
  deployOptionsFactory,
  deployQToken,
  deployQuantConfig,
  deployAssetsRegistry,
  mockERC20,
};
