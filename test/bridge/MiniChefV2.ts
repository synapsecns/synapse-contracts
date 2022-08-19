import { expect, assert } from "chai";
import {
  advanceTime,
  advanceTimeAndBlock,
  advanceBlockTo,
  advanceBlock,
  prepare,
  deploy,
  getBigNumber,
  ADDRESS_ZERO,
} from "./utilities";
const { BigNumber } = require("ethers");
import { ethers } from "hardhat";
import { solidity } from "ethereum-waffle";
import chai from "chai";
chai.use(solidity);

describe("MiniChefV2", function () {
  before(async function () {
    await prepare(this, [
      "MiniChefV2",
      "SynapseERC20",
      "ERC20Mock",
      "RewarderMock",
      "RewarderBrokenMock",
    ]);
    await deploy(this, [["brokenRewarder", this.RewarderBrokenMock]]);
  });

  beforeEach(async function () {
    await deploy(this, [["synapse", this.ERC20Mock, ["Dummy", "DummyT", getBigNumber(0)]]]);

    await deploy(this, [
      ["lp", this.ERC20Mock, ["LP Token", "LPT", getBigNumber(10)]],
      ["dummy", this.ERC20Mock, ["Dummy", "DummyT", getBigNumber(10)]],
      ["chef", this.MiniChefV2, [this.synapse.address]],
      ["rlp", this.ERC20Mock, ["LP", "rLPT", getBigNumber(10)]],
      ["r", this.ERC20Mock, ["Reward", "RewardT", getBigNumber(100000)]],
    ]);
    await deploy(this, [
      ["rewarder", this.RewarderMock, [getBigNumber(1), this.r.address, this.chef.address]],
    ]);

    await this.synapse.mint(this.chef.address, getBigNumber(10000));
    await this.lp.approve(this.chef.address, getBigNumber(10));
    await this.chef.setSynapsePerSecond("10000000000000000");
    await this.rlp.transfer(this.bob.address, getBigNumber(1));
  });

  describe("PoolLength", function () {
    it("PoolLength should execute", async function () {
      await this.chef.add(10, this.rlp.address, this.rewarder.address);
      expect(await this.chef.poolLength()).to.be.equal(1);
    });
  });

  describe("Set", function () {
    it("Should emit event LogSetPool", async function () {
      await this.chef.add(10, this.rlp.address, this.rewarder.address);
      await expect(this.chef.set(0, 10, this.dummy.address, false))
        .to.emit(this.chef, "LogSetPool")
        .withArgs(0, 10, this.rewarder.address, false);
      await expect(this.chef.set(0, 10, this.dummy.address, true))
        .to.emit(this.chef, "LogSetPool")
        .withArgs(0, 10, this.dummy.address, true);
    });

    it("Should revert if invalid pool", async function () {
      let err;
      try {
        await this.chef.set(0, 10, this.rewarder.address, false);
      } catch (e) {
        err = e;
      }

      assert.equal(
        err.toString(),
        "Error: VM Exception while processing transaction: invalid opcode"
      );
    });
  });

  describe("PendingSynapse", function () {
    it("PendingSynapse should equal ExpectedSynapse", async function () {
      await this.chef.add(10, this.rlp.address, this.rewarder.address);
      await this.rlp.approve(this.chef.address, getBigNumber(10));
      let log = await this.chef.deposit(0, getBigNumber(1), this.alice.address);
      await advanceTime(86400);
      let log2 = await this.chef.updatePool(0);
      let timestamp2 = (await ethers.provider.getBlock(log2.blockNumber)).timestamp;
      let timestamp = (await ethers.provider.getBlock(log.blockNumber)).timestamp;
      let expectedSynapse = BigNumber.from("10000000000000000").mul(timestamp2 - timestamp);
      let pendingSynapse = await this.chef.pendingSynapse(0, this.alice.address);
      expect(pendingSynapse).to.be.equal(expectedSynapse);
    });
    it("When time is lastRewardTime", async function () {
      await this.chef.add(10, this.rlp.address, this.rewarder.address);
      await this.rlp.approve(this.chef.address, getBigNumber(10));
      let log = await this.chef.deposit(0, getBigNumber(1), this.alice.address);
      await advanceBlockTo(3);
      let log2 = await this.chef.updatePool(0);
      let timestamp2 = (await ethers.provider.getBlock(log2.blockNumber)).timestamp;
      let timestamp = (await ethers.provider.getBlock(log.blockNumber)).timestamp;
      let expectedSynapse = BigNumber.from("10000000000000000").mul(timestamp2 - timestamp);
      let pendingSynapse = await this.chef.pendingSynapse(0, this.alice.address);
      expect(pendingSynapse).to.be.equal(expectedSynapse);
    });
  });

  describe("MassUpdatePools", function () {
    it("Should call updatePool", async function () {
      await this.chef.add(10, this.rlp.address, this.rewarder.address);
      await advanceBlockTo(1);
      await this.chef.massUpdatePools([0]);
      //expect('updatePool').to.be.calledOnContract(); //not suported by heardhat
      //expect('updatePool').to.be.calledOnContractWith(0); //not suported by heardhat
    });

    it("Updating invalid pools should fail", async function () {
      let err;
      try {
        await this.chef.massUpdatePools([0, 10000, 100000]);
      } catch (e) {
        err = e;
      }

      assert.equal(
        err.toString(),
        "Error: VM Exception while processing transaction: invalid opcode"
      );
    });
  });

  describe("Add", function () {
    it("Should add pool with reward token multiplier", async function () {
      await expect(this.chef.add(10, this.rlp.address, this.rewarder.address))
        .to.emit(this.chef, "LogPoolAddition")
        .withArgs(0, 10, this.rlp.address, this.rewarder.address);
    });
  });

  describe("UpdatePool", function () {
    it("Should emit event LogUpdatePool", async function () {
      await this.chef.add(10, this.rlp.address, this.rewarder.address);
      await advanceBlockTo(1);
      await expect(this.chef.updatePool(0))
        .to.emit(this.chef, "LogUpdatePool")
        .withArgs(
          0,
          (
            await this.chef.poolInfo(0)
          ).lastRewardTime,
          await this.rlp.balanceOf(this.chef.address),
          (
            await this.chef.poolInfo(0)
          ).accSynapsePerShare
        );
    });

    it("Should take else path", async function () {
      await this.chef.add(10, this.rlp.address, this.rewarder.address);
      await advanceBlockTo(1);
      await this.chef.batch(
        [
          this.chef.interface.encodeFunctionData("updatePool", [0]),
          this.chef.interface.encodeFunctionData("updatePool", [0]),
        ],
        true
      );
    });
  });

  describe("Deposit", function () {
    it("Depositing 0 amount", async function () {
      await this.chef.add(10, this.rlp.address, this.rewarder.address);
      await this.rlp.approve(this.chef.address, getBigNumber(10));
      await expect(this.chef.deposit(0, getBigNumber(0), this.alice.address))
        .to.emit(this.chef, "Deposit")
        .withArgs(this.alice.address, 0, 0, this.alice.address);
    });

    it("Depositing into non-existent pool should fail", async function () {
      let err;
      try {
        await this.chef.deposit(1001, getBigNumber(0), this.alice.address);
      } catch (e) {
        err = e;
      }

      assert.equal(
        err.toString(),
        "Error: VM Exception while processing transaction: invalid opcode"
      );
    });
  });

  describe("Withdraw", function () {
    it("Withdraw 0 amount", async function () {
      await this.chef.add(10, this.rlp.address, this.rewarder.address);
      await expect(this.chef.withdraw(0, getBigNumber(0), this.alice.address))
        .to.emit(this.chef, "Withdraw")
        .withArgs(this.alice.address, 0, 0, this.alice.address);
    });
  });

  describe("Harvest", function () {
    it("Should give back the correct amount of SYNAPSE and reward", async function () {
      await this.r.transfer(this.rewarder.address, getBigNumber(100000));
      await this.chef.add(10, this.rlp.address, this.rewarder.address);
      await this.rlp.approve(this.chef.address, getBigNumber(10));
      expect(await this.chef.lpToken(0)).to.be.equal(this.rlp.address);
      let log = await this.chef.deposit(0, getBigNumber(1), this.alice.address);
      await advanceTime(86400);
      let log2 = await this.chef.withdraw(0, getBigNumber(1), this.alice.address);
      let timestamp2 = (await ethers.provider.getBlock(log2.blockNumber)).timestamp;
      let timestamp = (await ethers.provider.getBlock(log.blockNumber)).timestamp;
      let expectedSynapse = BigNumber.from("10000000000000000").mul(timestamp2 - timestamp);
      expect((await this.chef.userInfo(0, this.alice.address)).rewardDebt).to.be.equal(
        "-" + expectedSynapse
      );
      await this.chef.harvest(0, this.alice.address);
      expect(await this.synapse.balanceOf(this.alice.address))
        .to.be.equal(await this.r.balanceOf(this.alice.address))
        .to.be.equal(expectedSynapse);
    });
    it("Harvest with empty user balance", async function () {
      await this.chef.add(10, this.rlp.address, this.rewarder.address);
      await this.chef.harvest(0, this.alice.address);
    });

    it("Harvest for SYNAPSE-only pool", async function () {
      await this.chef.add(10, this.rlp.address, ADDRESS_ZERO);
      await this.rlp.approve(this.chef.address, getBigNumber(10));
      expect(await this.chef.lpToken(0)).to.be.equal(this.rlp.address);
      let log = await this.chef.deposit(0, getBigNumber(1), this.alice.address);
      await advanceBlock();
      let log2 = await this.chef.withdraw(0, getBigNumber(1), this.alice.address);
      let timestamp2 = (await ethers.provider.getBlock(log2.blockNumber)).timestamp;
      let timestamp = (await ethers.provider.getBlock(log.blockNumber)).timestamp;
      let expectedSynapse = BigNumber.from("10000000000000000").mul(timestamp2 - timestamp);
      expect((await this.chef.userInfo(0, this.alice.address)).rewardDebt).to.be.equal(
        "-" + expectedSynapse
      );
      await this.chef.harvest(0, this.alice.address);
      expect(await this.synapse.balanceOf(this.alice.address)).to.be.equal(expectedSynapse);
    });
  });

  describe("EmergencyWithdraw", function () {
    it("Should emit event EmergencyWithdraw", async function () {
      await this.r.transfer(this.rewarder.address, getBigNumber(100000));
      await this.chef.add(10, this.rlp.address, this.rewarder.address);
      await this.rlp.approve(this.chef.address, getBigNumber(10));
      await this.chef.deposit(0, getBigNumber(1), this.bob.address);
      //await this.chef.emergencyWithdraw(0, this.alice.address)
      await expect(this.chef.connect(this.bob).emergencyWithdraw(0, this.bob.address))
        .to.emit(this.chef, "EmergencyWithdraw")
        .withArgs(this.bob.address, 0, getBigNumber(1), this.bob.address);
    });
  });
});
