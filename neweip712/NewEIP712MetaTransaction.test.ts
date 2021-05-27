import { Wallet } from "@ethersproject/wallet";
import { ethers } from "hardhat";
import NewEIP712MetaTransactionJSON from "../artifacts/contracts/NewEIP712MetaTransaction.sol/NewEIP712MetaTransaction.json";
import { NewEIP712MetaTransaction } from "../typechain";
import { expect } from "./setup";
import { deployContract, getActionsSignedData, provider } from "./testUtils";

describe("NewEIP712MetaTransaction", () => {
  let deployer: Wallet;
  let metaTxContract: NewEIP712MetaTransaction;
  before(async () => {
    [deployer] = await provider.getWallets();
    const MetaTxContract = await deployContract(
      deployer,
      NewEIP712MetaTransactionJSON,
      ["Quant Protocol", "0.2.0"]
    );

    metaTxContract = <NewEIP712MetaTransaction>(
      new ethers.Contract(
        MetaTxContract.address,
        MetaTxContract.interface,
        deployer
      )
    );
  });

  it("Should get a valid signature", async () => {
    const actions = {
      actionName: "withdraw",
      from: deployer.address,
      to: deployer.address,
      amount: 0,
    };
    // {
    //   actionName: "deposit",
    //   from: deployer.address,
    //   to: deployer.address,
    //   amount: 0,
    // },

    // const signedActions = await metaTxContract.hashActions(actions);

    const signedData = await getActionsSignedData(
      parseInt((await metaTxContract.getNonce(deployer.address)).toString()),
      deployer,
      metaTxContract.address,
      actions
    );

    await expect(
      metaTxContract
        .connect(deployer)
        .executeMetaTransaction(
          deployer.address,
          actions,
          signedData.r,
          signedData.s,
          signedData.v
        )
    )
      .to.emit(metaTxContract, "MetaTransactionVerified")
      .withArgs([true, signedData.r, signedData.s, signedData.v]);
  });
});
