import GnosisSafeL2Artifact from "@gnosis.pm/safe-contracts/build/artifacts/contracts/GnosisSafeL2.sol/GnosisSafeL2.json";
import { executeContractCallWithSigners } from "@gnosis.pm/safe-contracts/dist/utils/execution";
import * as dotenv from "dotenv";
import { Wallet } from "ethers";
import { ethers } from "hardhat";
import { getWalletFromMnemonic } from "../test/testUtils";
import { AssetsRegistry, ChainlinkOracleManager } from "../typechain";
dotenv.config();

const mnemonic =
  process.env.MNEMONIC ||
  "word soft garden squirrel this lift object foot someone boost certain provide";

(async () => {
  let deployer: Wallet;
  let user1: Wallet;
  let user2: Wallet;
  let user3: Wallet;

  const signers = ([deployer, user1, user2, user3] = [...Array(5).keys()].map(
    (i) => getWalletFromMnemonic(mnemonic, i, ethers.provider)
  ));

  const chainlinkOracleManager = <ChainlinkOracleManager>(
    await ethers.getContractAt(
      "ChainlinkOracleManager",
      "0x5551aB86F158606C06F81649831cdd09830698fA"
    )
  );

  const assetsRegistry = <AssetsRegistry>(
    await ethers.getContractAt(
      "AssetsRegistry",
      "0xA85806Ef7944dB6aDfcFB7002BA0bC321436e320"
    )
  );

  const quantProtocolMultisig = new ethers.Contract(
    "0x48b6484c677d58da4d9e36ca15224c8ca6bf94a8",
    GnosisSafeL2Artifact.abi,
    deployer
  );

  await executeContractCallWithSigners(
    quantProtocolMultisig,
    assetsRegistry,
    "addAssetWithOptionalERC20Methods",
    ["0x1b86e5322a589f065bd40f0114664ca40d78164b"],
    [deployer, user1, user2]
  );
})();
