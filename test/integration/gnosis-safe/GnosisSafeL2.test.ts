import GnosisSafeL2Artifact from "@gnosis.pm/safe-contracts/build/artifacts/contracts/GnosisSafeL2.sol/GnosisSafeL2.json";
import GnosisSafeProxyFactoryArtifact from "@gnosis.pm/safe-contracts/build/artifacts/contracts/proxies/GnosisSafeProxyFactory.sol/GnosisSafeProxyFactory.json";
import { calculateProxyAddress } from "@gnosis.pm/safe-contracts/dist/utils/proxies";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";
import { beforeEach, describe } from "mocha";
import { expect } from "../../setup";
import { GnosisSafeL2 } from "./types";

const { AddressZero, Zero } = ethers.constants;

describe("GnosisSafeL2 integration tests", () => {
  let deployer: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;
  let gnosisSafeL2: GnosisSafeL2;
  let quantMultisig: GnosisSafeL2;
  let gnosisSafeProxyFactory;
  let owners: Array<string>;

  const confirmationThreshold = ethers.BigNumber.from("2"); // 2/3 confirmations/signatures required for a transaction
  const gnosisSafeVersion = "1.3.0";

  before(async () => {
    const signers = ([deployer, user1, user2, user3] = (
      await ethers.getSigners()
    ).slice(0, 4));

    owners = signers.slice(1).map((signer) => signer.address);
  });

  beforeEach(async () => {
    const GnosisSafeL2 = new ethers.ContractFactory(
      GnosisSafeL2Artifact.abi,
      GnosisSafeL2Artifact.bytecode,
      deployer
    );

    // singleton to be used by the Proxy Factory to create a new Safe (multisig)
    gnosisSafeL2 = <GnosisSafeL2>await GnosisSafeL2.deploy();

    const GnosisSafeProxyFactory = new ethers.ContractFactory(
      GnosisSafeProxyFactoryArtifact.abi,
      GnosisSafeProxyFactoryArtifact.bytecode,
      deployer
    );

    gnosisSafeProxyFactory = await GnosisSafeProxyFactory.deploy();

    const saltNonce = ethers.BigNumber.from("133742999");
    const initCode = "0x";

    // calculate the address of the Safe once it gets deployed
    const proxyAddress = await calculateProxyAddress(
      gnosisSafeProxyFactory,
      gnosisSafeL2.address,
      initCode,
      saltNonce.toString()
    );

    await gnosisSafeProxyFactory.createProxyWithNonce(
      gnosisSafeL2.address,
      initCode,
      saltNonce
    );

    quantMultisig = gnosisSafeL2.attach(proxyAddress);

    // Initial Safe setup
    const to = AddressZero;
    const data = "0x";
    const fallbackHandler = AddressZero;
    const paymentToken = AddressZero; // ETH on L1, Matic on Polygon PoS side-chain
    const payment = Zero;
    const paymentReceiver = AddressZero;

    await quantMultisig.setup(
      owners,
      confirmationThreshold,
      to,
      data,
      fallbackHandler,
      paymentToken,
      payment,
      paymentReceiver
    );
  });

  it("Should create the Safe correctly", async () => {
    expect(await quantMultisig.VERSION()).to.equal(gnosisSafeVersion);
    expect(await quantMultisig.getOwners()).to.be.deep.equal(owners);
    expect(await quantMultisig.getThreshold()).to.equal(confirmationThreshold);
  });
});
