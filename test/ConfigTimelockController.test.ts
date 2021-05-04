import { BigNumber, BigNumberish, BytesLike, Signer } from "ethers";
import { ethers } from "hardhat";
import { beforeEach, describe, it } from "mocha";
import { ConfigTimelockController, QuantConfig } from "../typechain";
import { expect, provider } from "./setup";
import { deployConfigTimelockController, deployQuantConfig } from "./testUtils";

type scheduleParams = [
  string,
  BigNumberish,
  BytesLike,
  BytesLike,
  BytesLike,
  BigNumberish
];

describe("ConfigTimelockController", () => {
  let configTimelockController: ConfigTimelockController;
  let quantConfig: QuantConfig;
  let admin: Signer;
  let secondAccount: Signer;
  let delay: BigNumber;
  let predecessor: BytesLike;
  let salt: BytesLike;
  let scheduleCallData: scheduleParams;
  let id: string;

  const target = ethers.constants.AddressZero;
  const value = 0;
  const data = "0x00";
  const protocolFee = ethers.utils.id("PROTOCOL_FEE");

  const getBytes32Timestamp = async (): Promise<string> => {
    const timestamp = (
      (await provider.getBlock(await provider.getBlockNumber())).timestamp + 1
    ).toString();

    return ethers.utils.hexZeroPad(
      ethers.BigNumber.from(timestamp).toHexString(),
      32
    );
  };

  beforeEach(async () => {
    [admin, secondAccount] = await ethers.getSigners();

    delay = ethers.BigNumber.from(3600);

    configTimelockController = await deployConfigTimelockController(
      admin,
      delay
    );

    quantConfig = await deployQuantConfig(admin);

    predecessor = ethers.utils.formatBytes32String("");

    salt = ethers.utils.formatBytes32String(
      (
        await provider.getBlock(await provider.getBlockNumber())
      ).timestamp.toString()
    );

    scheduleCallData = [target, value, data, predecessor, salt, delay];

    id = await configTimelockController.hashOperation(
      target,
      value,
      data,
      predecessor,
      salt
    );
  });

  describe("setDelay", () => {
    it("Executors should be able to set new delays to protocol values setters that are longer than the minDelay", async () => {
      expect(await configTimelockController.minDelay()).to.equal(delay);

      expect(await configTimelockController.delays(protocolFee)).to.equal(
        ethers.BigNumber.from("0")
      );

      const newDelay = ethers.BigNumber.from(2 * 24 * 3600); // 2 days in seconds
      await configTimelockController
        .connect(admin)
        .setDelay(protocolFee, newDelay);
      expect(await configTimelockController.delays(protocolFee)).to.equal(
        newDelay
      );
    });

    it("Should set a delay to minDelay when an executor tries to set a delay shorter than it", async () => {
      const minDelay = ethers.BigNumber.from(4 * 24 * 3600); // 4 days in seconds
      configTimelockController = await deployConfigTimelockController(
        admin,
        minDelay
      );

      const newDelay = ethers.BigNumber.from(2 * 24 * 3600);
      await configTimelockController
        .connect(admin)
        .setDelay(protocolFee, newDelay);

      expect(await configTimelockController.delays(protocolFee)).to.equal(
        minDelay
      );
    });

    it("Should revert when a non-executor tries to set a new delay for a protocol value setter", async () => {
      await expect(
        configTimelockController
          .connect(secondAccount)
          .setDelay(protocolFee, ethers.BigNumber.from(24 * 3600))
      ).to.be.revertedWith("TimelockController: sender requires permission");
    });

    describe("schedule", () => {
      it("Should revert when trying to schedule function calls to protocol value setters while specifying a custom delay", async () => {
        await expect(
          configTimelockController
            .connect(admin)
            .schedule(
              quantConfig.address,
              value,
              quantConfig.interface.encodeFunctionData("setProtocolAddress", [
                ethers.utils.id("assetsRegistry"),
                ethers.constants.AddressZero,
              ]),
              predecessor,
              salt,
              delay
            )
        ).to.be.revertedWith(
          "ConfigTimelockController: Can not schedule changes to a protocol value with an arbitrary delay"
        );
      });

      it("Should revert when a non-proposer tries to schedule a function call", async () => {
        await expect(
          configTimelockController
            .connect(secondAccount)
            .schedule(...scheduleCallData)
        ).to.be.revertedWith("TimelockController: sender requires permission");
      });

      it("Proposers should be able to schedule function calls", async () => {
        await expect(
          configTimelockController.connect(admin).schedule(...scheduleCallData)
        )
          .to.emit(configTimelockController, "CallScheduled")
          .withArgs(id, 0, target, value, data, predecessor, delay);
      });
    });

    describe("scheduleSetProtocolAddress", () => {
      it("Should revert when a non-proposer tries to schedule setting a protocol address", async () => {
        await expect(
          configTimelockController
            .connect(secondAccount)
            .scheduleSetProtocolAddress(
              ethers.utils.id("oracleRegistry"),
              ethers.constants.AddressZero,
              quantConfig.address
            )
        ).to.be.revertedWith("TimelockController: sender requires permission");
      });

      it("Proposers should be able to schedule calls to setProtocolAddress in the QuantConfig", async () => {
        const registryAddress = ethers.Wallet.createRandom().address;

        const oracleRegistry = ethers.utils.id("oracleRegistry");

        const callData = quantConfig.interface.encodeFunctionData(
          "setProtocolAddress",
          [oracleRegistry, registryAddress]
        );

        const id = await configTimelockController.hashOperation(
          quantConfig.address,
          0,
          callData,
          predecessor,
          await getBytes32Timestamp()
        );

        await expect(
          configTimelockController
            .connect(admin)
            .scheduleSetProtocolAddress(
              ethers.utils.id("oracleRegistry"),
              registryAddress,
              quantConfig.address
            )
        )
          .to.emit(configTimelockController, "CallScheduled")
          .withArgs(
            id,
            0,
            quantConfig.address,
            0,
            callData,
            predecessor,
            delay
          );
      });
    });

    describe("scheduleSetProtocolUint256", () => {
      it("Should revert when a non-proposer tries to schedule setting a protocol uint256", async () => {
        await expect(
          configTimelockController
            .connect(secondAccount)
            .scheduleSetProtocolUint256(
              protocolFee,
              ethers.BigNumber.from("0"),
              quantConfig.address
            )
        ).to.be.revertedWith("TimelockController: sender requires permission");
      });

      it("Proposers should be able to schedule calls to setProtocolUint256 in the QuantConfig", async () => {
        const newProtocoFee = ethers.BigNumber.from("1000");

        const callData = quantConfig.interface.encodeFunctionData(
          "setProtocolUint256",
          [protocolFee, newProtocoFee]
        );

        const id = await configTimelockController.hashOperation(
          quantConfig.address,
          0,
          callData,
          predecessor,
          await getBytes32Timestamp()
        );

        await expect(
          configTimelockController
            .connect(admin)
            .scheduleSetProtocolUint256(
              protocolFee,
              newProtocoFee,
              quantConfig.address
            )
        )
          .to.emit(configTimelockController, "CallScheduled")
          .withArgs(
            id,
            0,
            quantConfig.address,
            0,
            callData,
            predecessor,
            delay
          );
      });
    });

    describe("scheduleSetProtocolBoolean", () => {
      it("Should revert when a non-proposer tries to schedule setting a protocol boolean", async () => {
        await expect(
          configTimelockController
            .connect(secondAccount)
            .scheduleSetProtocolBoolean(
              ethers.utils.id("oracleRegistry"),
              false,
              quantConfig.address
            )
        ).to.be.revertedWith("TimelockController: sender requires permission");
      });

      it("Proposers should be able to schedule calls to setProtocolBoolean in the QuantConfig", async () => {
        const isPriceRegistrySet = ethers.utils.id("isPriceRegistrySet");

        const callData = quantConfig.interface.encodeFunctionData(
          "setProtocolBoolean",
          [isPriceRegistrySet, true]
        );

        const id = await configTimelockController.hashOperation(
          quantConfig.address,
          0,
          callData,
          predecessor,
          await getBytes32Timestamp()
        );

        await expect(
          configTimelockController
            .connect(admin)
            .scheduleSetProtocolBoolean(
              isPriceRegistrySet,
              true,
              quantConfig.address
            )
        )
          .to.emit(configTimelockController, "CallScheduled")
          .withArgs(
            id,
            0,
            quantConfig.address,
            0,
            callData,
            predecessor,
            delay
          );
      });
    });

    //   describe("scheduleBatch", () => {
    //     it("Should revert when trying to schedule a batch of functions while specifying a custom delay", async () => {
    //       await expect(
    //         configTimelockController.scheduleBatch(
    //           [ethers.constants.AddressZero],
    //           [0],
    //           ["0x00"],
    //           someBytes32,
    //           someBytes32,
    //           delay
    //         )
    //       ).to.be.revertedWith(
    //         "ConfigTimelockController: Can not schedule a batch with arbitrary delays"
    //       );
    //     });
    //   });

    //   describe("scheduleWithDelay", () => {
    //     it("Should be able to schedule calls that don't have a delay stored, i.e., calls that are not changing a protocol value", async () => {
    //       const target = ethers.constants.AddressZero;
    //       const value = 0;
    //       const data = "0x00";
    //       const predecessor = someBytes32;

    //       const callData: scheduleWithDelayParams = [
    //         target,
    //         value,
    //         data,
    //         predecessor,
    //         someBytes32,
    //         someBytes32,
    //       ];

    //       const minDelay = ethers.BigNumber.from(4 * 24 * 3600); // 4 days in seconds
    //       configTimelockController = await deployConfigTimelockController(
    //         admin,
    //         minDelay
    //       );

    //       const id = await configTimelockController.hashOperation(
    //         target,
    //         value,
    //         data,
    //         predecessor,
    //         someBytes32
    //       );

    //       await expect(
    //         configTimelockController.connect(admin).scheduleWithDelay(...callData)
    //       )
    //         .to.emit(configTimelockController, "CallScheduled")
    //         .withArgs(id, 0, target, value, data, predecessor, minDelay);
    //     });

    //     it("Should be able to schedule calls that have a stored delay related to a protocol value", async () => {
    //       const protocolFeeDelay = ethers.BigNumber.from(3 * 24 * 3600); // 3 days in seconds
    //       await configTimelockController
    //         .connect(admin)
    //         .setDelay(protocolFee, protocolFeeDelay);

    //       const target = ethers.constants.AddressZero;
    //       const value = 0;
    //       const data = "0x00";
    //       const predecessor = someBytes32;

    //       const callData: scheduleWithDelayParams = [
    //         target,
    //         value,
    //         data,
    //         predecessor,
    //         someBytes32,
    //         protocolFee,
    //       ];

    //       const id = await configTimelockController.hashOperation(
    //         target,
    //         value,
    //         data,
    //         predecessor,
    //         someBytes32
    //       );

    //       await expect(
    //         configTimelockController.connect(admin).scheduleWithDelay(...callData)
    //       )
    //         .to.emit(configTimelockController, "CallScheduled")
    //         .withArgs(id, 0, target, value, data, predecessor, protocolFeeDelay);
    //     });

    //     it("Should revert when a non-proposer tries to schedule a function call", async () => {
    //       await expect(
    //         configTimelockController
    //           .connect(secondAccount)
    //           .scheduleWithDelay(
    //             ethers.constants.AddressZero,
    //             0,
    //             "0x00",
    //             someBytes32,
    //             someBytes32,
    //             someBytes32
    //           )
    //       ).to.be.revertedWith("TimelockController: sender requires permission");
    //     });
    //   });

    //   describe("scheduleBatchWithDelay", () => {
    //     it("Should revert when the targets and values arrays have different lengths", async () => {
    //       const targets = [ethers.constants.AddressZero];
    //       const values = [
    //         ethers.BigNumber.from("10"),
    //         ethers.BigNumber.from("2"),
    //       ];

    //       assert(targets.length !== values.length);

    //       await expect(
    //         configTimelockController
    //           .connect(admin)
    //           .scheduleBatchWithDelay(
    //             targets,
    //             values,
    //             ["0x00"],
    //             someBytes32,
    //             someBytes32,
    //             delay,
    //             [someBytes32]
    //           )
    //       ).to.be.revertedWith("ConfigTimelockController: length mismatch");
    //     });

    //     it("Should revert when the targets and datas arrays have different lengths", async () => {
    //       const targets = [ethers.constants.AddressZero];
    //       const datas = ["0x00", "0x01"];

    //       assert(targets.length !== datas.length);

    //       await expect(
    //         configTimelockController
    //           .connect(admin)
    //           .scheduleBatchWithDelay(
    //             targets,
    //             [ethers.BigNumber.from("10")],
    //             datas,
    //             someBytes32,
    //             someBytes32,
    //             delay,
    //             [someBytes32]
    //           )
    //       ).to.be.revertedWith("ConfigTimelockController: length mismatch");
    //     });

    //     it("Should revert when the targets and protocolValues arrays have different lengths", async () => {
    //       const targets = [ethers.constants.AddressZero];
    //       const protocolValues = [ethers.utils.id("assetsRegistry"), protocolFee];

    //       assert(targets.length !== protocolValues.length);

    //       await expect(
    //         configTimelockController
    //           .connect(admin)
    //           .scheduleBatchWithDelay(
    //             targets,
    //             [ethers.BigNumber.from("10")],
    //             ["0x00"],
    //             someBytes32,
    //             someBytes32,
    //             delay,
    //             protocolValues
    //           )
    //       ).to.be.revertedWith("ConfigTimelockController: length mismatch");
    //     });

    //     it(
    //       "Should revert when trying to schedule a batch of function calls with a delay lower than the minimum"
    //     );
    //   });
  });
});
