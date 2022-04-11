import { Signer } from "ethers"
import { getCurrentBlockTimestamp } from "./testUtils"
import { solidity } from "ethereum-waffle"
import { deployments, ethers } from "hardhat"

import chai from "chai"
import { GenericERC20, RateLimiter, SynapseBridge } from "../../build/typechain"
import epochSeconds from "@stdlib/time-now"
import { keccak256 } from "ethers/lib/utils"
import { randomBytes } from "crypto"
import { forkChain } from "../utils"
import { deployRateLimiter, setupForkedBridge } from "./utilities/bridge"

chai.use(solidity)
const { expect } = chai

describe("SynapseBridgeETH", async () => {
  // signers
  let signers: Array<Signer>
  let deployer: Signer
  let owner: Signer
  let limiter: Signer
  let nodeGroup: Signer
  let recipient: Signer
  let attacker: Signer

  // contracts
  let bridge: SynapseBridge
  let rateLimiter: RateLimiter
  let USDC: GenericERC20

  const BRIDGE_ADDRESS = "0x2796317b0fF8538F253012862c06787Adfb8cEb6"
  const NUSD = "0x1B84765dE8B7566e4cEAF4D0fD3c5aF52D3DdE4F"
  const NUSD_POOL = "0x1116898DdA4015eD8dDefb84b6e8Bc24528Af2d8"
  const SYN = "0x0f2D719407FdBeFF09D87557AbB7232601FD9F29"
  const WETH = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"

  const decimals = Math.pow(10, 6)

  // deploys the bridge, grants role. Rate limiter *must* be deployed first
  const setupTokens = async () => {
    const erc20Factory = await ethers.getContractFactory("GenericERC20")
    USDC = (await erc20Factory.deploy("USDC", "USDC", "6")) as GenericERC20
  }

  const setupTest = deployments.createFixture(
    async ({ deployments, ethers }) => {
      await deployments.fixture()

      signers = await ethers.getSigners()

      // assign roles
      deployer = signers[0]
      owner = signers[1]
      limiter = signers[2]
      nodeGroup = signers[3]
      recipient = signers[4]
      attacker = signers[5]

      rateLimiter = await deployRateLimiter(deployer, owner)
      bridge = await setupForkedBridge(
        rateLimiter,
        BRIDGE_ADDRESS,
        deployer,
        nodeGroup,
      )
      await setupTokens()
    },
  )

  beforeEach(async () => {
    // fork the chain
    await forkChain(process.env.ALCHEMY_API, 14555470)
    await setupTest()
  })

  // ammounts are multiplied by 10^6
  const setupAllowanceTest = async (
    tokenAddress: string,
    allowanceAmount: number,
    intervalMin: number = 60,
  ) => {
    const lastReset = Math.floor((await getCurrentBlockTimestamp()) / 60)
    allowanceAmount = allowanceAmount * decimals

    await expect(
      rateLimiter.setAllowance(
        tokenAddress,
        allowanceAmount,
        intervalMin,
        lastReset,
      ),
    ).to.be.not.reverted
  }

  it("Withdraw: should add to retry queue if rate limit hit", async () => {
    const mintAmount = 50

    await expect(USDC.mint(bridge.address, mintAmount * decimals))
    await setupAllowanceTest(USDC.address, 100)

    const kappa = keccak256(randomBytes(32))

    await expect(
      bridge
        .connect(nodeGroup)
        .withdraw(await recipient.getAddress(), USDC.address, 101, 50, kappa),
    ).to.be.not.reverted

    // make sure withdraw didn't happen
    expect(await USDC.balanceOf(bridge.address)).to.be.eq(
      (mintAmount * decimals).toString(),
    )


    // now retry. This should bypass the rate limiter
    await expect(rateLimiter.retryByKappa(kappa)).to.be.not.reverted
    expect(await bridge.kappaExists(kappa)).to.be.true
  })

  it("WithdrawAndRemove: should add to retry queue if rate limit hit", async () => {
    const allowanceAmount = 500
    const withdrawAmount = 1000

    await setupAllowanceTest(NUSD, allowanceAmount)
    const kappa = keccak256(randomBytes(32))

    await expect(
      bridge
        .connect(nodeGroup)
        .withdrawAndRemove(
          await recipient.getAddress(),
          NUSD,
          withdrawAmount,
          10,
          NUSD_POOL,
          1,
          withdrawAmount,
          epochSeconds(),
          kappa,
        ),
    ).to.be.not.reverted

    expect(await bridge.kappaExists(kappa)).to.be.false
    await expect(rateLimiter.retryByKappa(kappa)).to.be.not.reverted
    expect(await bridge.kappaExists(kappa)).to.be.true
  })

  it("Mint: should add to retry queue if rate limit hit", async () => {
    const allowanceAmount = 500
    const mintAmount = 1000

    await setupAllowanceTest(SYN, allowanceAmount)
    const kappa = keccak256(randomBytes(32))

    await expect(
      bridge
        .connect(nodeGroup)
        .mint(await recipient.getAddress(), SYN, mintAmount, 10, kappa),
    ).to.be.not.reverted

    expect(await bridge.kappaExists(kappa)).to.be.false
    await expect(rateLimiter.retryByKappa(kappa)).to.be.not.reverted
    expect(await bridge.kappaExists(kappa)).to.be.true
  })

  // check permissions
  it("SetChainGasAmount: should reject non-admin roles", async () => {
    await expect(
      bridge.connect(attacker).setChainGasAmount(1000),
    ).to.be.revertedWith("Not governance")
  })

  it("SetWethAddress: should reject non-admin roles", async () => {
    await expect(
      bridge.connect(attacker).setWethAddress(WETH),
    ).to.be.revertedWith("Not admin")
  })

  it.skip("SetRateLimiter: should reject non-governance roles", async () => {
    await expect(
      bridge
        .connect(attacker)
        .withdrawFees(USDC.address, await recipient.getAddress()),
    ).to.be.revertedWith("Not governance")
  })

  it("AddKappas: should reject non-admin roles", async () => {
    const kappas = [keccak256(randomBytes(32)), keccak256(randomBytes(32))]

    await expect(bridge.connect(attacker).addKappas(kappas)).to.be.revertedWith(
      "Not governance",
    )
  })

  it("WithdrawFees: should reject non-governance roles", async () => {
    await expect(
      bridge
        .connect(attacker)
        .withdrawFees(USDC.address, await recipient.getAddress()),
    ).to.be.revertedWith("Not governance")
  })

  it("Pause: should reject non-governance roles", async () => {
    await expect(bridge.connect(attacker).pause()).to.be.revertedWith(
      "Not governance",
    )
  })

  it("Unpause: should reject non-governance roles", async () => {
    await expect(bridge.connect(attacker).unpause()).to.be.revertedWith(
      "Not governance",
    )
  })
})
