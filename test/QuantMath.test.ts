import { assert, expect } from "chai";
import { ethers } from "hardhat";
import { QuantMathTester } from "../typechain";

describe("QuantMath lib", () => {
  let lib: QuantMathTester;

  before("set up contracts", async () => {
    const QuantMathTesterArtifact = await ethers.getContractFactory(
      "QuantMathTester"
    );
    lib = <QuantMathTester>await QuantMathTesterArtifact.deploy();
  });

  describe("Test Addition", () => {
    it("Should return 7e27 for 5e27 + 2e27", async () => {
      const a = await lib.testFromUnscaledInt(5);
      const b = await lib.testFromUnscaledInt(2);
      const expectedResult = ethers.utils.parseUnits("7", "27");

      assert.equal(
        (await lib.testAdd(a, b)).toString(),
        expectedResult.toString(),
        "adding result mismatch"
      );
    });
  });

  describe("Test subtraction", () => {
    it("Should return 2e27 for 7e27 - 5e27", async () => {
      const a = await lib.testFromUnscaledInt(7);
      const b = await lib.testFromUnscaledInt(5);
      const expectedResult = ethers.utils.parseUnits("2", 27);

      assert.equal(
        (await lib.testSub(a, b)).toString(),
        expectedResult.toString(),
        "subtraction result mismatch"
      );
    });

    it("Should return -2e27 for 5e27 - 7e27", async () => {
      const a = await lib.testFromUnscaledInt(7);
      const b = await lib.testFromUnscaledInt(5);
      const expectedResult = ethers.utils.parseUnits("-2", 27);

      assert.equal(
        (await lib.testSub(b, a)).toString(),
        expectedResult.toString(),
        "subtraction result mismatch"
      );
    });
  });

  describe("Test mul", () => {
    it("Should return 10e27 for 2e27 * 5e27", async () => {
      const a = await lib.testFromUnscaledInt(2);
      const b = await lib.testFromUnscaledInt(5);
      const expectedResult = ethers.utils.parseUnits("10", 27);

      assert.equal(
        (await lib.testMul(a, b)).toString(),
        expectedResult.toString(),
        "multiplication result mismatch"
      );
    });

    it("Should return 10 for -2 * -5", async () => {
      const a = await lib.testFromUnscaledInt(-2);
      const b = await lib.testFromUnscaledInt(-5);
      const expectedResult = ethers.utils.parseUnits("10", 27);

      assert.equal(
        (await lib.testMul(a, b)).toString(),
        expectedResult.toString(),
        "multiplication result mismatch"
      );
    });

    it("Should return 10 for -2 * 5", async () => {
      const a = await lib.testFromUnscaledInt(-2);
      const b = await lib.testFromUnscaledInt(5);
      const expectedResult = ethers.utils.parseUnits("-10", 27);

      assert.equal(
        (await lib.testMul(a, b)).toString(),
        expectedResult.toString(),
        "multiplication result mismatch"
      );
    });

    it("Should return 10 for 2 * -5", async () => {
      const a = await lib.testFromUnscaledInt(2);
      const b = await lib.testFromUnscaledInt(-5);
      const expectedResult = ethers.utils.parseUnits("-10", 27);

      assert.equal(
        (await lib.testMul(a, b)).toString(),
        expectedResult.toString(),
        "multiplication result mismatch"
      );
    });

    it("Should return 0 for 0 * 5e27", async () => {
      const a = await lib.testFromUnscaledInt(0);
      const b = await lib.testFromUnscaledInt(5);

      assert.equal(
        (await lib.testMul(a, b)).toString(),
        "0",
        "multiplication result mismatch"
      );
    });

    it("Should discard numbers < 1e-27", async () => {
      // 1e-27 * 2e-27 = 2 * 1e-54, should be discarded
      const a = { value: 1 };
      const b = { value: 2 };
      assert.equal(
        (await lib.testMul(a, b)).toString(),
        "0",
        "multiplication result mismatch"
      );

      // 1e-27 * 2e-1 = 2 * 1e-28, should be discarded
      const c = { value: 1 };
      const d = { value: ethers.utils.parseUnits("2", "26") };
      assert.equal(
        (await lib.testMul(c, d)).toString(),
        "0",
        "multiplication result mismatch"
      );

      // 1e-9 * 2e-18 = 2 * e-27, should not be discarded
      const e = { value: ethers.utils.parseUnits("1", "18") };
      const f = { value: ethers.utils.parseUnits("2", "9") };
      assert.equal(
        (await lib.testMul(e, f)).toString(),
        "2",
        "multiplication result mismatch"
      );
    });

    it("Should return 1e40 for 1e11 * 1e11", async () => {
      // max int: 2^255 = 5.7896045e+76
      // this is represented as 1e38
      const a = await lib.testFromUnscaledInt(
        ethers.utils.parseUnits("1", "11")
      );
      const expectedResult = await lib.testFromUnscaledInt(
        ethers.utils.parseUnits("1", "22")
      );
      assert.equal(
        (await lib.testMul(a, a)).toString(),
        expectedResult.value.toString(),
        "multiplication result mismatch"
      );
    });

    it("Should return overflow error when number is too big", async () => {
      // max int: 2^255 = 5.7896045e+76
      const b = { value: ethers.utils.parseUnits("2", "40") };
      const c = { value: ethers.utils.parseUnits("3", "40") };
      // this should overflow because 6e+76 > Max Int
      await expect(lib.testMul(b, c)).to.be.revertedWith(
        "SignedSafeMath: multiplication overflow"
      );
    });
  });

  describe("Test div", () => {
    it("Should return 2e27 for 10e27 divided by 5e27", async () => {
      const a = await lib.testFromUnscaledInt(10);
      const b = await lib.testFromUnscaledInt(5);
      const expectedResult = ethers.utils.parseUnits("2", 27);

      assert.equal(
        (await lib.testDiv(a, b)).toString(),
        expectedResult.toString(),
        "division result mismatch"
      );
    });

    it("Should return -2e27 for -10e27 divided by 5e27", async () => {
      const a = await lib.testFromUnscaledInt(-10);
      const b = await lib.testFromUnscaledInt(5);
      const expectedResult = ethers.utils.parseUnits("-2", 27);

      assert.equal(
        (await lib.testDiv(a, b)).toString(),
        expectedResult.toString(),
        "division result mismatch"
      );
    });

    it("Should return -2e27 for 10e27 divided by -5e27", async () => {
      const a = await lib.testFromUnscaledInt(10);
      const b = await lib.testFromUnscaledInt(-5);
      const expectedResult = ethers.utils.parseUnits("-2", 27);

      assert.equal(
        (await lib.testDiv(a, b)).toString(),
        expectedResult.toString(),
        "division result mismatch"
      );
    });
  });

  describe("Test min", () => {
    it("Should return 3e27 between 3e27 and 5e27", async () => {
      const a = await lib.testFromUnscaledInt(3);
      const b = await lib.testFromUnscaledInt(5);
      const expectedResult = ethers.utils.parseUnits("3", 27);

      assert.equal(
        (await lib.testMin(a, b)).toString(),
        expectedResult.toString(),
        "minimum result mismatch"
      );
    });

    it("Should return -2e27 between -2e27 and 2e27", async () => {
      const a = await lib.testFromUnscaledInt(-2);
      const b = await lib.testFromUnscaledInt(-2);
      const expectedResult = ethers.utils.parseUnits("-2", 27);

      assert.equal(
        (await lib.testMin(a, b)).toString(),
        expectedResult.toString(),
        "minimum result mismatch"
      );
    });
  });

  describe("Test max", () => {
    it("Should return 3e27 between 3e27 and 1e27", async () => {
      const a = await lib.testFromUnscaledInt(3);
      const b = await lib.testFromUnscaledInt(1);
      const expectedResult = ethers.utils.parseUnits("3", 27);

      assert.equal(
        (await lib.testMax(a, b)).toString(),
        expectedResult.toString(),
        "maximum result mismatch"
      );
    });
  });

  describe("Test comparison operator", () => {
    it("Should return if two int are equal or not", async () => {
      const a = await lib.testFromUnscaledInt(3);
      const b = await lib.testFromUnscaledInt(3);
      const expectedResult = true;

      assert.equal(
        await lib.testIsEqual(a, b),
        expectedResult,
        "isEqual result mismatch"
      );
    });

    it("Should return if a is greater than b or not", async () => {
      const a = await lib.testFromUnscaledInt(-2);
      const b = await lib.testFromUnscaledInt(2);
      const expectedResult = false;

      assert.equal(
        await lib.testIsGreaterThan(a, b),
        expectedResult,
        "isGreaterThan result mismatch"
      );
    });

    it("Should return if a is greater than or equal b", async () => {
      const a = await lib.testFromUnscaledInt(-2);
      const b = await lib.testFromUnscaledInt(-2);
      const expectedResult = true;

      assert.equal(
        await lib.testIsGreaterThanOrEqual(a, b),
        expectedResult,
        "isGreaterThanOrEqual result mismatch"
      );
    });

    it("Should return if a is less than b or not", async () => {
      const a = await lib.testFromUnscaledInt(-2);
      const b = await lib.testFromUnscaledInt(0);
      const expectedResult = true;

      assert.equal(
        await lib.testIsLessThan(a, b),
        expectedResult,
        "isLessThan result mismatch"
      );
    });

    it("Should return if a is less than or equal b", async () => {
      const a = await lib.testFromUnscaledInt(0);
      const b = await lib.testFromUnscaledInt(0);
      const expectedResult = true;

      assert.equal(
        await lib.testIsLessThanOrEqual(a, b),
        expectedResult,
        "isLessThanOrEqual result mismatch"
      );
    });
  });
});
