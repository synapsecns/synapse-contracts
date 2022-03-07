import { expect, assert } from "chai"
import { advanceTime, deploy, getBigNumber } from "../utils"
const { BigNumber } = require("ethers")
import { ethers } from "hardhat"
import { solidity } from "ethereum-waffle"
import chai from "chai"
import { getUserTokenBalance, ZERO_ADDRESS } from "../utils"
import { prepare } from "./utils"
chai.use(solidity)

describe("BonusChef", function () {
  const ADD = 0
  const REM = 1
  const HAR = 2
  const R_H = 3
  const RST = 4

  async function setupPool(self) {
    await self.chef.set(0, 10, self.bonusChef.address, true)
    // add reward pool with duration of 1000s
    await self.bonusChef.addRewardPool(self.r.address, 1000)
  }

  async function startPool(self) {
    await self.bonusChef.notifyRewardAmount(self.r.address, getBigNumber(10))
    let startTime = await self.bonusChef.lastUpdateTime(self.r.address)
    let finalTime = await self.bonusChef.periodFinish(self.r.address)
    let rewardRate = await self.bonusChef.rewardRate(self.r.address)
    await self.users.setData(startTime, finalTime, rewardRate)
  }

  async function makeActions(self, actionsData: Array<Array<number>>, pid = 0) {
    await self.users.makeActions(
      pid,
      actionsData.map((x) => x[0]),
      actionsData.map((x) => getBigNumber(x[1])),
    )
  }

  async function checkRescue(bonusChef, token, owner) {
    let amount = await getUserTokenBalance(bonusChef.address, token)
    await expect(() => bonusChef.rescue(token.address)).to.changeTokenBalances(
      token,
      [owner, bonusChef],
      [amount, amount.mul(-1)],
    )
  }

  before(async function () {
    await prepare(this, [
      "MiniChefV21",
      "ERC20Mock",
      "UserMock",
      "Users",
      "BonusChef",
    ])
  })

  beforeEach(async function () {
    await deploy(this, [
      ["syn", this.ERC20Mock, ["SYN", "SYN", getBigNumber(0)]],
    ])

    await deploy(this, [
      ["chef", this.MiniChefV21, [this.syn.address]],
      ["lp", this.ERC20Mock, ["LPT", "LP Token", getBigNumber(3000)]],
      ["r", this.ERC20Mock, ["RT", "Reward Token", getBigNumber(1000)]],
    ])

    await deploy(this, [
      ["userA", this.UserMock, [this.chef.address, [this.r.address], "User A"]],
      ["userB", this.UserMock, [this.chef.address, [this.r.address], "User B"]],
      ["userC", this.UserMock, [this.chef.address, [this.r.address], "User C"]],
    ])

    await deploy(this, [
      [
        "users",
        this.Users,
        [[this.userA.address, this.userB.address, this.userC.address]],
      ],
    ])

    // Supply users with LP tokens to stake
    await this.lp.transfer(this.userA.address, getBigNumber(1000))
    await this.lp.transfer(this.userB.address, getBigNumber(1000))
    await this.lp.transfer(this.userC.address, getBigNumber(1000))

    await this.chef.add(10, this.lp.address, ZERO_ADDRESS)

    await deploy(this, [
      ["bonusChef", this.BonusChef, [this.chef.address, 0, this.alice.address]],
    ])

    await this.syn.mint(this.chef.address, getBigNumber(10000))
    await this.chef.setSynapsePerSecond("10000000000000000")
    await this.r.approve(this.bonusChef.address, getBigNumber(1000))
  })

  describe("Sanity Checks", function () {
    it("Can't start the pool without setting up MiniChef and BonusChef", async function () {
      await makeActions(this, [
        [ADD, 1],
        [ADD, 4],
        [ADD, 5],
      ])

      // Can't add the reward token, if MiniChef isn't set up
      await expect(
        this.bonusChef.addRewardPool(this.r.address, 1000),
      ).to.be.revertedWith("MiniChef pool isn't set up")

      // Can't start the rewards, if there's no reward pool
      await expect(
        this.bonusChef.notifyRewardAmount(this.r.address, getBigNumber(10)),
      ).to.be.revertedWith("Pool is not added")

      // Set up MiniChef first
      await this.chef.set(0, 10, this.bonusChef.address, true)

      // Still can't start the rewards, there's no reward pool
      await expect(
        this.bonusChef.notifyRewardAmount(this.r.address, getBigNumber(10)),
      ).to.be.revertedWith("Pool is not added")

      // Now we add the bonus reward pool
      await this.bonusChef.addRewardPool(this.r.address, 1000)
      // Only now the rewards can be added
      await this.bonusChef.notifyRewardAmount(this.r.address, getBigNumber(10))
    })

    it("Only governance can inactivate pool and/or rescue tokens", async function () {
      await setupPool(this)
      await startPool(this)
      await advanceTime(1000)

      // Some guy can't inactivate the pool
      await expect(
        this.bonusChef.connect(this.bob).inactivateRewardPool(this.r.address),
      ).to.be.revertedWith("!governance")
      await expect(
        this.bonusChef.connect(this.bob).inactivateRewardPoolByIndex(0),
      ).to.be.revertedWith("!governance")

      await this.bonusChef.inactivateRewardPool(this.r.address)

      // Sifu can't rescue unclaimed tokens
      await expect(
        this.bonusChef.connect(this.bob).rescue(this.r.address),
      ).to.be.revertedWith("!governance")

      await checkRescue(this.bonusChef, this.r, this.alice)

      await expect(
        this.bonusChef.notifyRewardAmount(this.r.address, getBigNumber(10)),
      ).to.be.revertedWith("Pool is not added")

      await setupPool(this)
      await this.bonusChef.notifyRewardAmount(this.r.address, getBigNumber(10))
    })

    it("User rewards are emptied after rescuing", async function () {
      await makeActions(this, [
        [ADD, 1],
        [ADD, 4],
        [ADD, 5],
      ])

      await setupPool(this)
      await startPool(this)

      await advanceTime(1000)
      await this.bonusChef.inactivateRewardPool(this.r.address)
      await checkRescue(this.bonusChef, this.r, this.alice)

      await makeActions(this, [
        [REM, 1],
        [RST, 0],
        [REM, 1],
      ])

      // Rewards were rescued, so all unclaimed rewards are lost
      await this.users.clearUnclaimed()

      await setupPool(this)
      await startPool(this)
      await advanceTime(100)

      // this will check if the bonus rewards are correct after
      // rescue + restart
      await makeActions(this, [
        [HAR, 0],
        [HAR, 0],
        [HAR, 0],
      ])
    })

    it("Role for supplying rewards is granted correctly", async function () {
      await this.lp.mint(this.bob.address, getBigNumber(1))
      await this.lp
        .connect(this.bob)
        .approve(this.bonusChef.address, getBigNumber(1))

      await setupPool(this)
      await this.bonusChef.addRewardPool(this.lp.address, 100)
      await this.bonusChef.notifyRewardAmount(this.r.address, getBigNumber(10))

      await this.bonusChef.addRewardsDistribution(this.bob.address)
      await this.bonusChef
        .connect(this.bob)
        .notifyRewardAmount(this.lp.address, getBigNumber(1))

      await advanceTime(1000)

      // Some guy still can't inactivate the pool
      await expect(
        this.bonusChef.connect(this.bob).inactivateRewardPool(this.r.address),
      ).to.be.revertedWith("!governance")

      await expect(
        this.bonusChef.connect(this.bob).inactivateRewardPool(this.lp.address),
      ).to.be.revertedWith("!governance")

      await this.bonusChef.inactivateRewardPool(this.r.address)
      await this.bonusChef.inactivateRewardPool(this.lp.address)

      // Stealing funds not allowed
      await expect(
        this.bonusChef.connect(this.bob).rescue(this.r.address),
      ).to.be.revertedWith("!governance")
      await expect(
        this.bonusChef.connect(this.bob).rescue(this.lp.address),
      ).to.be.revertedWith("!governance")

      await checkRescue(this.bonusChef, this.r, this.alice)
      await checkRescue(this.bonusChef, this.lp, this.alice)
    })

    it("Governance role is transferred correctly", async function () {
      await expect(
        this.bonusChef.connect(this.bob).transferGovernance(this.bob.address),
      ).to.be.revertedWith("!governance")

      await this.bonusChef.addRewardsDistribution(this.bob.address)
      await expect(
        this.bonusChef.connect(this.bob).transferGovernance(this.bob.address),
      ).to.be.revertedWith("!governance")

      await this.bonusChef.transferGovernance(this.carol.address)
      await expect(
        this.bonusChef.transferGovernance(this.alice.address),
      ).to.be.revertedWith("!governance")
      await expect(
        this.bonusChef.addRewardsDistribution(this.alice.address),
      ).to.be.revertedWith("!governance")

      await this.bonusChef
        .connect(this.carol)
        .addRewardsDistribution(this.alice.address)
      await expect(
        this.bonusChef.transferGovernance(this.alice.address),
      ).to.be.revertedWith("!governance")

      await this.bonusChef
        .connect(this.carol)
        .transferGovernance(this.alice.address)
      await expect(
        this.bonusChef.connect(this.carol).transferGovernance(this.bob.address),
      ).to.be.revertedWith("!governance")

      await this.bonusChef.transferGovernance(this.bob.address)
      await this.bonusChef
        .connect(this.bob)
        .transferGovernance(this.alice.address)

      // OK, governance role is not a toy, let's stop tossing it around
    })

    it("Only reward supplier can supply rewards", async function () {
      await setupPool(this)
      await this.r.mint(this.bob.address, getBigNumber(1))
      await expect(
        this.bonusChef
          .connect(this.bob)
          .notifyRewardAmount(this.r.address, getBigNumber(1)),
      ).to.be.revertedWith("!rewardsDistribution")
      await this.bonusChef.notifyRewardAmount(this.r.address, getBigNumber(10))
    })

    it("Bonus Pool params are correct", async function () {
      await setupPool(this)
      let amount = getBigNumber(10)
      let log = await this.bonusChef.notifyRewardAmount(this.r.address, amount)
      let timestamp = (await ethers.provider.getBlock(log.blockNumber))
        .timestamp

      await advanceTime(100)
      expect(await this.bonusChef.lastUpdateTime(this.r.address)).to.eq(
        timestamp,
      )
      expect(await this.bonusChef.periodFinish(this.r.address)).to.eq(
        timestamp + 1000,
      )
      expect(await this.bonusChef.rewardRate(this.r.address)).to.eq(
        amount.div(1000),
      )
    })

    it("Bonus Pool params are correct after restart", async function () {
      await setupPool(this)
      let amount = getBigNumber(5)
      await this.bonusChef.notifyRewardAmount(this.r.address, amount)
      await advanceTime(1000)
      await this.bonusChef.inactivateRewardPool(this.r.address)

      await setupPool(this)
      let log = await this.bonusChef.notifyRewardAmount(this.r.address, amount)
      let timestamp = (await ethers.provider.getBlock(log.blockNumber))
        .timestamp

      await advanceTime(100)
      expect(await this.bonusChef.lastUpdateTime(this.r.address)).to.eq(
        timestamp,
      )
      expect(await this.bonusChef.periodFinish(this.r.address)).to.eq(
        timestamp + 1000,
      )
      expect(await this.bonusChef.rewardRate(this.r.address)).to.eq(
        amount.div(1000),
      )
    })

    it("Bonus pool params are correct after prolongation", async function () {
      await setupPool(this)
      let amount = getBigNumber(5)
      let log = await this.bonusChef.notifyRewardAmount(this.r.address, amount)
      let timestamp0 = (await ethers.provider.getBlock(log.blockNumber))
        .timestamp

      await advanceTime(500)
      log = await this.bonusChef.notifyRewardAmount(this.r.address, amount)
      let timestamp = (await ethers.provider.getBlock(log.blockNumber))
        .timestamp

      let remainder = amount.mul(timestamp - timestamp0).div(1000)
      let rewardRate = amount.add(remainder).div(1000)
      await advanceTime(100)
      expect(await this.bonusChef.lastUpdateTime(this.r.address)).to.eq(
        timestamp,
      )
      expect(await this.bonusChef.periodFinish(this.r.address)).to.eq(
        timestamp + 1000,
      )
      expect(await this.bonusChef.rewardRate(this.r.address)).to.eq(rewardRate)
    })
  })

  describe("Test runs", function () {
    beforeEach(async function () {
      await makeActions(this, [
        [ADD, 1],
        [ADD, 4],
        [ADD, 5],
      ])
      // [1, 4, 5]
      await setupPool(this)
      await startPool(this)
    })

    it("Correct bonus rewards", async function () {
      await advanceTime(50)
      await makeActions(this, [
        [ADD, 3],
        [RST, 0],
        [REM, 5],
      ])
      // [4, 4, 0]

      await advanceTime(50)
      await makeActions(this, [
        [HAR, 0],
        [ADD, 0],
        [RST, 0],
      ])
      // [4, 4, 0]

      await advanceTime(50)
      await makeActions(this, [
        [REM, 4],
        [REM, 3],
        [RST, 0],
      ])
      // [0, 1, 0]

      await advanceTime(100)
      await makeActions(this, [
        [ADD, 8],
        [REM, 1],
        [ADD, 2],
      ])
      // [8, 0, 2]

      await advanceTime(50)
      await makeActions(this, [
        [R_H, 7],
        [ADD, 2],
        [HAR, 0],
      ])
      // [1, 2, 2]

      await advanceTime(1000)
      await makeActions(this, [
        [RST, 0],
        [ADD, 1],
        [R_H, 1],
      ])

      // [1, 3, 1], but the bonus rewards have ended
      expect(await this.bonusChef.periodFinish(this.r.address)).to.eq(
        await this.bonusChef.lastTimeRewardApplicable(this.r.address),
      )
      await advanceTime(100)
      await makeActions(this, [
        [HAR, 0],
        [HAR, 0],
        [HAR, 0],
      ])
      await makeActions(this, [
        [REM, 1],
        [REM, 3],
        [REM, 1],
      ])
      expect(await getUserTokenBalance(this.chef.address, this.lp)).to.eq(0)
    })

    it("Correct bonus rewards when pool is empty", async function () {
      await advanceTime(50)
      await makeActions(this, [
        [RST, 0],
        [RST, 0],
        [REM, 5],
      ])
      // [1, 4, 0]

      await advanceTime(50)
      await makeActions(this, [
        [RST, 0],
        [REM, 4],
        [ADD, 0],
      ])
      // [1, 0, 0]

      await advanceTime(50)
      await makeActions(this, [
        [HAR, 0],
        [HAR, 0],
        [HAR, 0],
      ])
      // [1, 0, 0]
      await advanceTime(50)
      await makeActions(this, [
        [REM, 1],
        [ADD, 0],
        [ADD, 0],
      ])
      // [0, 0, 0]

      await advanceTime(50)
      await makeActions(this, [
        [HAR, 0],
        [ADD, 0],
        [REM, 0],
      ])

      await advanceTime(50)
      await makeActions(this, [
        [R_H, 0],
        [ADD, 0],
        [ADD, 1],
      ])
      // until now pool was empty, so these rewards will not be paid
      // governance can rescue them
      // [0, 0, 1]
      await advanceTime(1000)
      await makeActions(this, [
        [ADD, 4],
        [ADD, 4],
        [ADD, 1],
      ])
      // [4, 4, 2] but the rewards are ended
      await advanceTime(100)
      await makeActions(this, [
        [REM, 4],
        [REM, 4],
        [REM, 2],
      ])

      await makeActions(this, [
        [R_H, 0],
        [REM, 0],
        [ADD, 0],
      ])

      expect(await getUserTokenBalance(this.chef.address, this.lp)).to.eq(0)
      expect(await getUserTokenBalance(this.bonusChef.address, this.r)).to.gt(0)
      await this.bonusChef.inactivateRewardPool(this.r.address)
      await checkRescue(this.bonusChef, this.r, this.alice)
    })
  })
})
