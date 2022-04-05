import chai from "chai"
import { solidity } from "ethereum-waffle"
import { deployments, ethers } from "hardhat"
import { BigNumber, BigNumberish, Signer } from "ethers"
import Wallet from "ethereumjs-wallet"

import { CHAIN_ID } from "../../utils/network"
import { Address } from "hardhat-deploy/dist/types"
import { faker } from "@faker-js/faker"
import { includes } from "lodash"
import {
  BridgeConfigV3,
  GenericERC20,
  RateLimiterTest,
  RateLimiter
} from "../../build/typechain"
import epochSeconds from "@stdlib/time-now"

chai.use(solidity)
const { expect, assert } = chai

describe("Rate Limiter", () => {
  let signers: Array<Signer>
  let deployer: Signer
  let owner: Signer
  let attacker: Signer
  let rateLimiter: RateLimiter
  let rateLimiterTest: RateLimiterTest

  let USDC: GenericERC20
  let USDT: GenericERC20

  // number of minutes in an hour
  let hour: number = 60

  const setupTest = deployments.createFixture(
    async ({ deployments, ethers }) => {
      await deployments.fixture() // ensure you start from a fresh deployments
      signers = await ethers.getSigners()
      deployer = signers[0]
      owner = signers[1]
      attacker = signers[10]

      const rateLimiterFactory = await ethers.getContractFactory("RateLimiter")

      // deploy 2 test erc-20's
      const erc20Factory = await ethers.getContractFactory("GenericERC20")

      USDC = (await erc20Factory.deploy("USDC", "USDC", "6")) as GenericERC20
      USDT = (await erc20Factory.deploy("USDT", "USDT", "6")) as GenericERC20

      // deploy and initialize the rate limiter
      rateLimiter = (await rateLimiterFactory.deploy()) as RateLimiter
      await rateLimiter.initialize()

      const limiterRole = await rateLimiter.LIMITER_ROLE()
      const bridgeRole = await rateLimiter.BRIDGE_ROLE()
      await rateLimiter
        .connect(deployer)
        .grantRole(limiterRole, await owner.getAddress())

      // connect the bridge config v3 with the owner. For unauthorized tests, this can be overriden
      rateLimiter = rateLimiter.connect(owner)

      // deploy the rateLimiterTest
      const rateLimiterTestFactory = await ethers.getContractFactory(
        "RateLimiterTest",
      )
      rateLimiterTest =
        (await rateLimiterTestFactory.deploy()) as RateLimiterTest
      await rateLimiterTest.initialize(rateLimiter.address)

      // grant the bridge role to rateLimiterTest
      await rateLimiter
        .connect(deployer)
        .grantRole(bridgeRole, rateLimiterTest.address)
    },
  )

  beforeEach(async () => {
    await setupTest()
  })

  describe("set allowance test", () => {
    it("should set alowance correctly", async () => {
      const allowance = 100 * Math.pow(10, 6) // allowance of $100

      const lastReset = Math.floor(epochSeconds() / hour)

      // 1 hour
      await expect(
        rateLimiter.setAllowance(USDC.address, allowance, 60, lastReset),
      ).to.be.not.reverted

      let [amount, spent, resetTimeMin, lastResetMin] =
        await rateLimiter.getTokenAllowance(USDC.address)
      expect(allowance).to.be.eq(amount)
      expect(spent).to.be.eq(0)
      expect(resetTimeMin).to.be.eq(60)
      expect(lastResetMin).to.be.eq(lastReset)
    })

    it.only("should update allowance", async () => {
      const allowance = 100 * Math.pow(10, 6) // allowance of $100
      const lastReset = Math.floor(epochSeconds() / hour)

      // reset every hour after current epoch time to an allowance of $100
      expect(rateLimiter.setAllowance(USDC.address, allowance, hour, lastReset))
        .to.be.not.reverted

      // draw down $10 from allowance
      await expect(
        rateLimiterTest.storeCheckAndUpdateAllowance(
          USDC.address,
          10 * Math.pow(10, 6),
        ),
      ).to.be.not.reverted

      expect(await rateLimiterTest.getLastUpdateValue()).to.be.true

      let [amount, spent, resetTimeMin, lastResetMin] =
        await rateLimiter.getTokenAllowance(USDC.address)
      expect(amount).to.be.eq(amount)
      expect(spent).to.be.eq(10 * Math.pow(10, 6))
      expect(resetTimeMin).to.be.eq(60)
      expect(lastResetMin).to.be.eq(lastReset)
    })

    it("should return false if newSpent > allowance amount", async () => {
      const allowance = 1000 * Math.pow(10, 6) // allowance of $100
      const lastReset = Math.floor(epochSeconds() / hour)

      // reset every hour after current epoch time to an allowance of $100
      expect(rateLimiter.setAllowance(USDC.address, allowance, hour, lastReset))
        .to.be.not.reverted

      await expect(
        rateLimiterTest.storeCheckAndUpdateAllowance(USDC.address, allowance),
      ).to.be.not.reverted

      // make sure method returned false
      expect(await rateLimiterTest.getLastUpdateValue()).to.be.false

      // make sure values haven't been updated
      let [amount, spent, resetTimeMin, lastResetMin] =
        await rateLimiter.getTokenAllowance(USDC.address)

      expect(allowance).to.be.eq(amount)
      expect(spent).to.be.eq(0)
      expect(resetTimeMin).to.be.eq(60)
      expect(lastResetMin).to.be.eq(lastReset)
    })

      it("should reset allowance", async () => {
          const allowance = 1000 * Math.pow(10, 6) // allowance of $100
          const lastReset = Math.floor(epochSeconds() / hour)

          // reset every hour after current epoch time to an allowance of $100
          expect(rateLimiter.setAllowance(USDC.address, allowance, hour, lastReset))
              .to.be.not.reverted

          await expect(
              rateLimiterTest.storeCheckAndUpdateAllowance(USDC.address, 1),
          ).to.be.not.reverted

          // make sure method returned false
          console.log(await rateLimiterTest.getLastUpdateValue())
          expect(await rateLimiterTest.getLastUpdateValue()).to.be.true

          await expect(rateLimiter.resetAllowance(USDC.address)).to.be.not.reverted

          let [amount, spent, resetTimeMin, lastResetMin] =
              await rateLimiter.getTokenAllowance(USDC.address)

          expect(allowance).to.be.eq(amount)
          expect(spent).to.be.eq(0)
          expect(resetTimeMin).to.be.eq(60)
          expect(lastResetMin).to.be.eq(lastReset)
      })
  })
})
