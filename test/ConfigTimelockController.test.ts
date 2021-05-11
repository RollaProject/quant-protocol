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
        .withArgs(id, 0, quantConfig.address, 0, callData, predecessor, delay);
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
        .withArgs(id, 0, quantConfig.address, 0, callData, predecessor, delay);
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
        .withArgs(id, 0, quantConfig.address, 0, callData, predecessor, delay);
    });
  });

  describe("scheduleBatch", () => {
    it("Should revert when a non-proposer tries to schedule a batch of function calls", async () => {
      await expect(
        configTimelockController
          .connect(secondAccount)
          .scheduleBatch(
            [ethers.constants.AddressZero],
            [ethers.utils.parseEther("10")],
            ["0x00"],
            predecessor,
            salt,
            delay
          )
      ).to.be.revertedWith("TimelockController: sender requires permission");
    });

    it("Should revert when trying to schedule a batch with less values than targets", async () => {
      await expect(
        configTimelockController
          .connect(admin)
          .scheduleBatch(
            [ethers.constants.AddressZero, quantConfig.address],
            [ethers.utils.parseEther("2")],
            ["0x00", "0x00"],
            predecessor,
            salt,
            delay
          )
      ).to.be.revertedWith("TimelockController: length mismatch");
    });

    it("Should revert when trying to schedule a batch with less data values than targets", async () => {
      await expect(
        configTimelockController
          .connect(admin)
          .scheduleBatch(
            [ethers.constants.AddressZero, quantConfig.address],
            [ethers.utils.parseEther("5"), ethers.utils.parseEther("1")],
            ["0x00"],
            predecessor,
            salt,
            delay
          )
      ).to.be.revertedWith("TimelockController: length mismatch");
    });

    it("Should revert when trying to schedule a batch of calls containing changes to a protocol value while specifying a custom delay", async () => {
      const newProtocoFee = ethers.BigNumber.from("1000");

      const callData = quantConfig.interface.encodeFunctionData(
        "setProtocolUint256",
        [protocolFee, newProtocoFee]
      );

      await expect(
        configTimelockController
          .connect(admin)
          .scheduleBatch(
            [
              ethers.constants.AddressZero,
              quantConfig.address,
              ethers.Wallet.createRandom().address,
            ],
            [
              ethers.utils.parseEther("1"),
              ethers.BigNumber.from("0"),
              ethers.utils.parseEther("4"),
            ],
            ["0x00", callData, "0x00"],
            predecessor,
            salt,
            delay
          )
      ).to.be.revertedWith(
        "ConfigTimelockController: Can not schedule changes to a protocol value with an arbitrary delay"
      );
    });
  });

  describe("scheduleBatchSetProtocolAddress", () => {
    it("Should revert when a non-proposer tries to schedule a batch of setProtocolAddress calls", async () => {
      await expect(
        configTimelockController
          .connect(secondAccount)
          .scheduleBatchSetProtocolAddress(
            [protocolFee, ethers.utils.id("oracleRegistry")],
            [ethers.constants.AddressZero, ethers.constants.AddressZero],
            quantConfig.address
          )
      ).to.be.revertedWith("TimelockController: sender requires permission");
    });

    it("Should revert when a different number of addresses and protocol values is passed", async () => {
      await expect(
        configTimelockController
          .connect(admin)
          .scheduleBatchSetProtocolAddress(
            [protocolFee],
            [
              ethers.constants.AddressZero,
              ethers.Wallet.createRandom().address,
            ],
            quantConfig.address
          )
      ).to.be.revertedWith("ConfigTimelockController: length mismatch");
    });

    it("Proposers should be able to schedule batches of setProtocolAddress calls", async () => {
      const registryAddress = ethers.Wallet.createRandom().address;
      const feeCollectorAddress = ethers.Wallet.createRandom().address;

      const oracleRegistry = ethers.utils.id("oracleRegistry");
      const feeCollector = ethers.utils.id("feeCollector");

      const registryCallData = quantConfig.interface.encodeFunctionData(
        "setProtocolAddress",
        [oracleRegistry, registryAddress]
      );

      const feeCollectorCallData = quantConfig.interface.encodeFunctionData(
        "setProtocolAddress",
        [feeCollector, feeCollectorAddress]
      );

      const registryId = await configTimelockController.hashOperation(
        quantConfig.address,
        0,
        registryCallData,
        predecessor,
        await getBytes32Timestamp()
      );

      const feeCollectorId = await configTimelockController.hashOperation(
        quantConfig.address,
        0,
        feeCollectorCallData,
        predecessor,
        await getBytes32Timestamp()
      );

      await expect(
        configTimelockController
          .connect(admin)
          .scheduleBatchSetProtocolAddress(
            [oracleRegistry, feeCollector],
            [registryAddress, feeCollectorAddress],
            quantConfig.address
          )
      )
        .to.emit(configTimelockController, "CallScheduled")
        .withArgs(
          registryId,
          0,
          quantConfig.address,
          0,
          registryCallData,
          predecessor,
          delay
        )
        .emit(configTimelockController, "CallScheduled")
        .withArgs(
          feeCollectorId,
          0,
          quantConfig.address,
          0,
          feeCollectorCallData,
          predecessor,
          delay
        );
    });
  });

  describe("scheduleBatchSetProtocolUints", () => {
    it("Should revert when a non-proposer tries to schedule a batch of setProtocolUint256 calls", async () => {
      await expect(
        configTimelockController
          .connect(secondAccount)
          .scheduleBatchSetProtocolUints(
            [protocolFee, ethers.utils.id("maxOptionsDuration")],
            [ethers.BigNumber.from("0"), ethers.BigNumber.from(28 * 24 * 3600)],
            quantConfig.address
          )
      ).to.be.revertedWith("TimelockController: sender requires permission");
    });

    it("Should revert when a different number of addresses and protocol values is passed", async () => {
      await expect(
        configTimelockController
          .connect(admin)
          .scheduleBatchSetProtocolUints(
            [protocolFee],
            [ethers.BigNumber.from(0), ethers.utils.parseEther("10")],
            quantConfig.address
          )
      ).to.be.revertedWith("ConfigTimelockController: length mismatch");
    });

    it("Proposers should be able to schedule batches of setProtocolUint256 calls", async () => {
      const protocolFeeValue = ethers.BigNumber.from("10");
      const maxOptionsDurationValue = ethers.BigNumber.from(28 * 24 * 3600);

      const protocolFeeCalldata = quantConfig.interface.encodeFunctionData(
        "setProtocolUint256",
        [protocolFee, protocolFeeValue]
      );

      const maxOptionsDurationCallData = quantConfig.interface.encodeFunctionData(
        "setProtocolUint256",
        [ethers.utils.id("maxOptionsDuration"), maxOptionsDurationValue]
      );

      const protocolFeeId = await configTimelockController.hashOperation(
        quantConfig.address,
        0,
        protocolFeeCalldata,
        predecessor,
        await getBytes32Timestamp()
      );

      const maxOptionsDurationId = await configTimelockController.hashOperation(
        quantConfig.address,
        0,
        maxOptionsDurationCallData,
        predecessor,
        await getBytes32Timestamp()
      );

      await expect(
        configTimelockController
          .connect(admin)
          .scheduleBatchSetProtocolUints(
            [protocolFee, ethers.utils.id("maxOptionsDuration")],
            [protocolFeeValue, maxOptionsDurationValue],
            quantConfig.address
          )
      )
        .to.emit(configTimelockController, "CallScheduled")
        .withArgs(
          protocolFeeId,
          0,
          quantConfig.address,
          0,
          protocolFeeCalldata,
          predecessor,
          delay
        )
        .emit(configTimelockController, "CallScheduled")
        .withArgs(
          maxOptionsDurationId,
          0,
          quantConfig.address,
          0,
          maxOptionsDurationCallData,
          predecessor,
          delay
        );
    });
  });

  describe("scheduleBatchSetProtocolBooleans", () => {
    const isPaused = ethers.utils.id("isPaused");
    const isDeprecated = ethers.utils.id("isDeprecated");

    it("Should revert when a non-proposer tries to schedule a batch of setProtocolBoolean calls", async () => {
      await expect(
        configTimelockController
          .connect(secondAccount)
          .scheduleBatchSetProtocolBooleans(
            [isPaused, isDeprecated],
            [true, false],
            quantConfig.address
          )
      ).to.be.revertedWith("TimelockController: sender requires permission");
    });

    it("Should revert when a different number of booleans and protocol values is passed", async () => {
      await expect(
        configTimelockController
          .connect(admin)
          .scheduleBatchSetProtocolBooleans(
            [isPaused],
            [false, false],
            quantConfig.address
          )
      ).to.be.revertedWith("ConfigTimelockController: length mismatch");
    });

    it("Proposers should be able to schedule batches of setProtocolBoolean calls", async () => {
      const isPausedValue = false;
      const isDeprecatedValue = true;

      const isPausedCallData = quantConfig.interface.encodeFunctionData(
        "setProtocolBoolean",
        [isPaused, isPausedValue]
      );

      const isDeprecatedCallData = quantConfig.interface.encodeFunctionData(
        "setProtocolBoolean",
        [isDeprecated, isDeprecatedValue]
      );

      const isPausedId = await configTimelockController.hashOperation(
        quantConfig.address,
        0,
        isPausedCallData,
        predecessor,
        await getBytes32Timestamp()
      );

      const isDeprecatedId = await configTimelockController.hashOperation(
        quantConfig.address,
        0,
        isDeprecatedCallData,
        predecessor,
        await getBytes32Timestamp()
      );

      await expect(
        configTimelockController
          .connect(admin)
          .scheduleBatchSetProtocolBooleans(
            [isPaused, isDeprecated],
            [isPausedValue, isDeprecatedValue],
            quantConfig.address
          )
      )
        .to.emit(configTimelockController, "CallScheduled")
        .withArgs(
          isPausedId,
          0,
          quantConfig.address,
          0,
          isPausedCallData,
          predecessor,
          delay
        )
        .emit(configTimelockController, "CallScheduled")
        .withArgs(
          isDeprecatedId,
          0,
          quantConfig.address,
          0,
          isDeprecatedCallData,
          predecessor,
          delay
        );
    });
  });
});
