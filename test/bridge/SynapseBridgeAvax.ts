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

describe("SynapseBridgeAvax", async () => {
  // signers
  let signers: Array<Signer>
  let deployer: Signer
  let owner: Signer
  let limiter: Signer
  let nodeGroup: Signer
  let recipient: Signer

  const decimals = Math.pow(10, 6)
  const NUSD = "0xCFc37A6AB183dd4aED08C204D1c2773c0b1BDf46"
  const NUSD_POOL = "0xED2a7edd7413021d440b09D654f3b87712abAB66"

  // contracts
  let bridge: SynapseBridge
  let rateLimiter: RateLimiter

  const BRIDGE_ADDRESS = "0xC05e61d0E7a63D27546389B7aD62FdFf5A91aACE"

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

      rateLimiter = await deployRateLimiter(deployer, owner)
      bridge = await setupForkedBridge(
        rateLimiter,
        BRIDGE_ADDRESS,
        deployer,
        nodeGroup,
      )
    },
  )

  beforeEach(async () => {
    // fork the chain
    await forkChain(process.env.AVAX_API, 13229005)
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

  it("MintAndSwap: should add to retry queue if rate limit hit", async () => {
    const allowanceAmount = 500
    const mintAmount = 1000

    await setupAllowanceTest(NUSD, allowanceAmount)
    const kappa = keccak256(randomBytes(32))

    await expect(
      bridge
        .connect(nodeGroup)
        .mintAndSwap(
          await recipient.getAddress(),
          NUSD,
          mintAmount,
          10,
          NUSD_POOL,
          0,
          2,
          mintAmount,
          epochSeconds(),
          kappa,
        ),
    ).to.be.not.reverted

    expect(await bridge.kappaExists(kappa)).to.be.false
    await expect(rateLimiter.retryByKappa(kappa)).to.be.not.reverted
    expect(await bridge.kappaExists(kappa)).to.be.true
  })
})
