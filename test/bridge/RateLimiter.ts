import chai from "chai"
import { solidity } from "ethereum-waffle"
import { deployments, ethers } from "hardhat"
import { BigNumber, BigNumberish, Signer } from "ethers"
import Wallet from "ethereumjs-wallet"

import { RateLimiter } from "../../build/typechain/RateLimiter"
import { CHAIN_ID } from "../../utils/network"
import { Address } from "hardhat-deploy/dist/types"
import { faker } from "@faker-js/faker"
import { includes } from "lodash"
import {BridgeConfigV3, GenericERC20} from "../../build/typechain";
import epochSeconds from "@stdlib/time-now";

chai.use(solidity)
const { expect, assert } = chai


describe("Rate Limiter", () => {

    let signers: Array<Signer>
    let deployer: Signer
    let owner: Signer
    let attacker: Signer
    let rateLimiter: RateLimiter

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

            const rateLimiterFactory = await ethers.getContractFactory(
                "RateLimiter",
            )

            const erc20Factory = await ethers.getContractFactory("GenericERC20")

            USDC = (await erc20Factory.deploy("USDC", "USDC", "6")) as GenericERC20
            USDT = (await erc20Factory.deploy("USDT", "USDT", "6")) as GenericERC20

            rateLimiter = (await rateLimiterFactory.deploy()) as RateLimiter
            await rateLimiter.initialize();

            const limiterRole = await rateLimiter.LIMITER_ROLE()
            await rateLimiter
                .connect(deployer)
                .grantRole(limiterRole, await owner.getAddress())

            // connect the bridge config v3 with the owner. For unauthorized tests, this can be overriden
            rateLimiter = rateLimiter.connect(owner)
        },
    )

    beforeEach(async () => {
        await setupTest()
    })

    describe("set allowance test", () => {
        it("should set alowance correctly", async () => {
            const allowance = 100 * Math.pow(10, 6) // allowance of $100

            const lastReset = Math.floor(epochSeconds()/hour)

            // 1 hour
            await expect(await rateLimiter.setAllowance(USDC.address, allowance, 60, lastReset)).to.be.not.reverted

            let [amount, spent, resetTimeMin, lastResetMin, nonce] = await rateLimiter.getTokenAllowance(USDC.address)
            expect(allowance).to.be.eq(amount)
            expect(spent).to.be.eq(0)
            expect(resetTimeMin).to.be.eq(60)
            expect(lastResetMin).to.be.eq(lastReset)
            // initialized, but with no updates
            expect(nonce).to.be.eq(1)
        })

        it("should update allowance", async () => {
            // create a bridge as a signer and grant it the bridge role
            const bridge: Signer = signers[1]

            // grant our new bridge the role
            await rateLimiter.connect(deployer).grantRole(await rateLimiter.BRIDGE_ROLE(), await bridge.getAddress())
            // use rateLimiter as bridge
            const bridgeRateLimiter: RateLimiter = await rateLimiter.connect(bridge)

            const allowance = 100 * Math.pow(10, 6) // allowance of $100
            const lastReset = Math.floor(epochSeconds()/hour)

            // reset every hour after current epoch time to an allowance of $100
            expect(rateLimiter.setAllowance(USDC.address, allowance, hour, lastReset)).to.be.not.reverted

            // draw down $10 from allowance
           await expect(bridgeRateLimiter.checkAndUpdateAllowance(USDC.address, 10 * Math.pow(10, 6))).to.be.not.reverted
            // console.log(await bridgeRateLimiter.checkAndUpdateAllowance(USDC.address, 10 * Math.pow(10, 6)))


            let [amount, spent, resetTimeMin, lastResetMin, nonce] =  await rateLimiter.getTokenAllowance(USDC.address)
            expect(amount).to.be.eq(amount)
            expect(spent).to.be.eq(10 * Math.pow(10, 6))
            expect(resetTimeMin).to.be.eq(60)
            expect(lastResetMin).to.be.eq(lastReset)
            // initialized, but with no updates
            expect(nonce).to.be.eq(2)
        })
    })
})
