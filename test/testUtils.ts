import { MockContract } from "ethereum-waffle";
import { BigNumber, Signer } from "ethers";
import { ethers, upgrades, waffle } from "hardhat";
import ERC20 from "../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json";
import QTokenJSON from "../artifacts/contracts/protocol/options/QToken.sol/QToken.json";
import { QToken } from "../typechain/QToken";
import { QuantConfig } from "../typechain/QuantConfig";

const { deployContract, deployMockContract } = waffle;

const mockERC20 = async (
  deployer: Signer,
  tokenSymbol: string,
  tokenName?: string,
  decimals?: number
): Promise<MockContract> => {
  const erc20 = await deployMockContract(deployer, ERC20.abi);

  await erc20.mock.symbol.returns(tokenSymbol);

  if (tokenName !== undefined) {
    await erc20.mock.name.returns(tokenName);
  }
  if (decimals !== undefined) {
    await erc20.mock.decimals.returns(decimals);
  }

  return erc20;
};

const deployQuantConfig = async (admin: Signer): Promise<QuantConfig> => {
  const QuantConfig = await ethers.getContractFactory("QuantConfig");

  return <QuantConfig>(
    await upgrades.deployProxy(QuantConfig, [await admin.getAddress()])
  );
};

const createSampleOption = async (
  deployer: Signer,
  quantConfig: QuantConfig,
  underlyingAsset: string,
  strikeAsset: string,
  oracle: string = ethers.constants.AddressZero,
  strikePrice: BigNumber = ethers.utils.parseEther("1400"),
  expiryTime: BigNumber = ethers.BigNumber.from("1618592400"), // April 16th, 2021
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

export { createSampleOption, deployQuantConfig, mockERC20 };
