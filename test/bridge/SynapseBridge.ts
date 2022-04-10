import { BigNumber, Signer } from "ethers"
import {
  MAX_UINT256,
  TIME,
  ZERO_ADDRESS,
  asyncForEach,
  getCurrentBlockTimestamp,
  setNextTimestamp,
  setTimestamp,
  forceAdvanceOneBlock,
} from "./testUtils"
import { solidity } from "ethereum-waffle"
import { deployments, ethers, upgrades } from "hardhat"

import chai from "chai"
import { GenericERC20, RateLimiter, SynapseBridge } from "../../build/typechain"
import epochSeconds from "@stdlib/time-now"
import { keccak256 } from "ethers/lib/utils"
import { randomBytes } from "crypto"
import { forkChain } from "../utils"
import { addBridgeOwner, upgradeBridgeProxy } from "./utilities/fork"

chai.use(solidity)
const { expect } = chai

describe.only("SynapseBridge", async () => {
  const { get } = deployments

  // signers
  let signers: Array<Signer>
  let deployer: Signer
  let owner: Signer
  let limiter: Signer
  let nodeGroup: Signer
  let recipient: Signer

  // contracts
  let bridge: SynapseBridge
  let rateLimiter: RateLimiter
  let USDC: GenericERC20
  const BRIDGE_ADDRESS = "0x2796317b0fF8538F253012862c06787Adfb8cEb6"

  const decimals = Math.pow(10, 6)

  // deploy rateLimiter deploys the rate limiter contract, sets it to RateLimiter and
  // assigns owner the limiter role
  const deployRateLimiter = async () => {
    const rateLimiterFactory = await ethers.getContractFactory("RateLimiter")
    rateLimiter = (await rateLimiterFactory.deploy()) as RateLimiter
    await rateLimiter.initialize()

    const limiterRole = await rateLimiter.LIMITER_ROLE()
    await rateLimiter
      .connect(deployer)
      .grantRole(limiterRole, await owner.getAddress())

    const governanceRole = await rateLimiter.GOVERNANCE_ROLE()

    await rateLimiter
      .connect(deployer)
      .grantRole(governanceRole, await owner.getAddress())

    // connect the bridge config v3 with the owner. For unauthorized tests, this can be overriden
    rateLimiter = rateLimiter.connect(owner)
  }

  // deploys the bridge, grants role. Rate limiter *must* be deployed first
  const upgradeBridge = async () => {
    if (rateLimiter == null) {
      throw "rate limiter must be deployed before bridge"
    }

    // deploy and initialize the rate limiter
    const synapseBridgeFactory = await ethers.getContractFactory(
      "SynapseBridge",
    )

    await upgradeBridgeProxy(BRIDGE_ADDRESS)

    // attach to the deployed bridge
    bridge = (await synapseBridgeFactory.attach(
      BRIDGE_ADDRESS,
    )) as SynapseBridge
    await addBridgeOwner(BRIDGE_ADDRESS, await deployer.getAddress())

    // grant rate limiter role on bridge to rate limiter
    const rateLimiterRole = await bridge.RATE_LIMITER_ROLE()
    await bridge
      .connect(deployer)
      .grantRole(rateLimiterRole, rateLimiter.address)

    await bridge.setRateLimiter(rateLimiter.address)

    const nodeGroupRole = await bridge.NODEGROUP_ROLE()
    await bridge
      .connect(deployer)
      .grantRole(nodeGroupRole, await nodeGroup.getAddress())

    bridge = await bridge.connect(nodeGroup)

    await rateLimiter
      .connect(deployer)
      .grantRole(await rateLimiter.BRIDGE_ROLE(), bridge.address)

    await rateLimiter.setBridgeAddress(bridge.address)
  }

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

      await deployRateLimiter()
      await upgradeBridge()
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
    token: GenericERC20,
    allowanceAmount: number,
    mintAmount: number,
    intervalMin: number = 60,
  ) => {
    const lastReset = Math.floor((await getCurrentBlockTimestamp()) / 60)
    allowanceAmount = allowanceAmount * decimals

    await expect(
      rateLimiter.setAllowance(
        token.address,
        allowanceAmount,
        intervalMin,
        lastReset,
      ),
    ).to.be.not.reverted
    await expect(USDC.mint(bridge.address, mintAmount * decimals))
  }

  it("Withdraw: should add to retry queue if rate limit hit", async () => {
    const mintAmount = 50
    await setupAllowanceTest(USDC, 100, mintAmount)

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
})
