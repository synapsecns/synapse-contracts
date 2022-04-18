import { Signer } from "ethers"
import { getCurrentBlockTimestamp } from "./testUtils"
import { solidity } from "ethereum-waffle"
import { deployments, ethers } from "hardhat"

import chai from "chai"
import {
  GenericERC20,
  RateLimiter,
  SynapseBridge,
  SynapseERC20,
} from "../../build/typechain"
import { keccak256 } from "ethers/lib/utils"
import { randomBytes } from "crypto"
import { forkChain, impersonateAccount, MAX_UINT256 } from "../utils"
import { deployRateLimiter, setupForkedBridge } from "./utilities/bridge"
import { advanceTime, getBigNumber } from "./utilities"

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

  const setupAllowanceTest = async (
    tokenAddress: string,
    allowanceAmount: number,
    intervalMin: number = 60,
  ) => {
    const lastReset = Math.floor((await getCurrentBlockTimestamp()) / 60)

    await rateLimiter.setAllowance(
      tokenAddress,
      allowanceAmount,
      intervalMin,
      lastReset,
    )
  }

  it("Withdraw: should add to retry queue only if rate limit hit", async () => {
    const mintAmount = getBigNumber(1000, 6)
    const allowanceAmount = getBigNumber(100, 6)
    const firstAmount = getBigNumber(42, 6)
    const secondAmount = allowanceAmount.sub(firstAmount).add(1)

    await USDC.mint(bridge.address, mintAmount)
    await setupAllowanceTest(USDC.address, allowanceAmount)

    let kappa = keccak256(randomBytes(32))

    await expect(
      bridge
        .connect(nodeGroup)
        .withdraw(
          await recipient.getAddress(),
          USDC.address,
          firstAmount,
          0,
          kappa,
        ),
    ).to.be.not.reverted
    // This should NOT BE rate limited
    expect(await bridge.kappaExists(kappa)).to.be.true

    kappa = keccak256(randomBytes(32))
    await expect(
      bridge
        .connect(nodeGroup)
        .withdraw(
          await recipient.getAddress(),
          USDC.address,
          secondAmount,
          0,
          kappa,
        ),
    ).to.be.not.reverted

    // This should BE rate limited
    expect(await bridge.kappaExists(kappa)).to.be.false

    // now retry. This should bypass the rate limiter
    await expect(rateLimiter.retryByKappa(kappa)).to.be.not.reverted
    expect(await bridge.kappaExists(kappa)).to.be.true
  })

  it("WithdrawAndRemove: should add to retry queue only if rate limit hit", async () => {
    const allowanceAmount = getBigNumber(100)
    const firstAmount = getBigNumber(69)
    const secondAmount = allowanceAmount.sub(firstAmount).add(1)

    await setupAllowanceTest(NUSD, allowanceAmount)
    let kappa = keccak256(randomBytes(32))

    await bridge
      .connect(nodeGroup)
      .withdrawAndRemove(
        await recipient.getAddress(),
        NUSD,
        firstAmount,
        0,
        NUSD_POOL,
        1,
        0,
        MAX_UINT256,
        kappa,
      )

    // This should NOT BE rate limited
    expect(await bridge.kappaExists(kappa)).to.be.true

    kappa = keccak256(randomBytes(32))

    await bridge
      .connect(nodeGroup)
      .withdrawAndRemove(
        await recipient.getAddress(),
        NUSD,
        secondAmount,
        0,
        NUSD_POOL,
        1,
        0,
        MAX_UINT256,
        kappa,
      )
    // This should BE rate limited
    expect(await bridge.kappaExists(kappa)).to.be.false

    await rateLimiter.retryByKappa(kappa)
    expect(await bridge.kappaExists(kappa)).to.be.true
  })

  it("Mint: should add to retry queue only if rate limit hit", async () => {
    const allowanceAmount = getBigNumber(100)
    const firstAmount = getBigNumber(100)
    const secondAmount = allowanceAmount.sub(firstAmount).add(1)

    await setupAllowanceTest(SYN, allowanceAmount)
    let kappa = keccak256(randomBytes(32))

    await bridge
      .connect(nodeGroup)
      .mint(await recipient.getAddress(), SYN, firstAmount, 0, kappa)

    // This should NOT BE rate limited
    expect(await bridge.kappaExists(kappa)).to.be.true

    kappa = keccak256(randomBytes(32))
    await bridge
      .connect(nodeGroup)
      .mint(await recipient.getAddress(), SYN, secondAmount, 0, kappa)
    // This should BE rate limited
    expect(await bridge.kappaExists(kappa)).to.be.false
    await rateLimiter.retryByKappa(kappa)
    expect(await bridge.kappaExists(kappa)).to.be.true
  })

  it("RetryCount: should be able to clear the Retry Queue", async () => {
    const allowanceAmount = getBigNumber(100)
    const amount = allowanceAmount.add(1)
    await setupAllowanceTest(SYN, allowanceAmount)

    // Should be able to fully clear twice
    for (let i = 0; i <= 1; ++i) {
      const kappas = [
        keccak256(randomBytes(32)),
        keccak256(randomBytes(32)),
        keccak256(randomBytes(32)),
        keccak256(randomBytes(32)),
      ]

      for (let kappa of kappas) {
        await bridge
          .connect(nodeGroup)
          .mint(await recipient.getAddress(), SYN, amount, 0, kappa)

        // This should BE rate limited
        expect(await bridge.kappaExists(kappa)).to.be.false
      }

      await rateLimiter.retryCount(kappas.length)

      for (let kappa of kappas) {
        expect(await bridge.kappaExists(kappa)).to.be.true
      }
    }
  })

  it("RetryCount: should work correctly after retryByKappa", async () => {
    const allowanceAmount = getBigNumber(100)
    const amount = allowanceAmount.add(1)
    const kappas = [
      keccak256(randomBytes(32)),
      keccak256(randomBytes(32)),
      keccak256(randomBytes(32)),
      keccak256(randomBytes(32)),
    ]

    await setupAllowanceTest(SYN, allowanceAmount)

    for (let kappa of kappas) {
      await bridge
        .connect(nodeGroup)
        .mint(await recipient.getAddress(), SYN, amount, 0, kappa)

      // This should BE rate limited
      expect(await bridge.kappaExists(kappa)).to.be.false
    }

    await rateLimiter.retryByKappa(kappas[1])
    expect(await bridge.kappaExists(kappas[1])).to.be.true

    await rateLimiter.retryByKappa(kappas[3])
    expect(await bridge.kappaExists(kappas[3])).to.be.true

    await rateLimiter.retryCount(kappas.length)

    for (let kappa of kappas) {
      expect(await bridge.kappaExists(kappa)).to.be.true
    }
  })

  it("Permissionless timeout for retryByKappa", async () => {
    const allowanceAmount = getBigNumber(100)
    const amount = allowanceAmount.add(1)

    const kappa = keccak256(randomBytes(32))
    await setupAllowanceTest(SYN, allowanceAmount)

    await bridge
      .connect(nodeGroup)
      .mint(await recipient.getAddress(), SYN, amount, 0, kappa)

    // This should BE rate limited
    expect(await bridge.kappaExists(kappa)).to.be.false

    await expect(
      rateLimiter.connect(deployer).retryByKappa(kappa),
    ).to.be.revertedWith("Retry timeout not finished")

    await advanceTime(360 * 60)

    await rateLimiter.connect(deployer).retryByKappa(kappa)
    // Timeout finished, should be good to go
    expect(await bridge.kappaExists(kappa)).to.be.true
  })

  it("Failed retried txs are saved for later use", async () => {
    let syn = (await ethers.getContractAt("SynapseERC20", SYN)) as SynapseERC20
    const adminAddress = await syn.getRoleMember(
      await syn.DEFAULT_ADMIN_ROLE(),
      0,
    )
    const admin = await impersonateAccount(adminAddress)
    syn = syn.connect(admin)

    const allowanceAmount = getBigNumber(100)
    const amount = allowanceAmount.add(1)

    await setupAllowanceTest(SYN, allowanceAmount)
    await setupAllowanceTest(NUSD, allowanceAmount)

    const kappas = [
      keccak256(randomBytes(32)),
      keccak256(randomBytes(32)),
      keccak256(randomBytes(32)),
    ]

    // [withdraw NUSD, mint SYN, withdraw NUSD]
    for (let index in kappas) {
      const kappa = kappas[index]
      if (index === "1") {
        await bridge
          .connect(nodeGroup)
          .mint(await recipient.getAddress(), SYN, amount, 0, kappa)
      } else {
        await bridge
          .connect(nodeGroup)
          .withdraw(await recipient.getAddress(), NUSD, amount, 0, kappa)
      }
      // This should BE rate limited
      expect(await bridge.kappaExists(kappa)).to.be.false
    }

    // Minting SYN is not possible => minting tx will fail on retry
    await syn.revokeRole(await syn.MINTER_ROLE(), bridge.address)

    await rateLimiter.retryCount(kappas.length)
    expect(await bridge.kappaExists(kappas[0])).to.be.true
    expect(await bridge.kappaExists(kappas[1])).to.be.false
    expect(await bridge.kappaExists(kappas[2])).to.be.true

    await syn.grantRole(await syn.MINTER_ROLE(), bridge.address)

    await rateLimiter.retryByKappa(kappas[1])
    expect(await bridge.kappaExists(kappas[1])).to.be.true
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

  it("SetRateLimiter: should reject non-admin roles", async () => {
    await expect(
      bridge.connect(attacker).setRateLimiter(rateLimiter.address),
    ).to.be.revertedWith("Not admin")
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
