import { Signer } from "ethers"
import { getCurrentBlockTimestamp } from "./testUtils"
import { String } from "typescript-string-operations"
import { solidity } from "ethereum-waffle"
import { deployments, ethers } from "hardhat"

import chai from "chai"
import { GenericERC20, RateLimiter, SynapseBridge } from "../../build/typechain"
import epochSeconds from "@stdlib/time-now"
import { id, keccak256 } from "ethers/lib/utils"
import { randomBytes } from "crypto"
import { forkChain } from "../utils"
import { deployRateLimiter, setupForkedBridge } from "./utilities/bridge"
import sinon from "sinon"
import upgrade from "./upgrade_config.json"

chai.use(solidity)
const { expect } = chai

const chains = Object.keys(upgrade)

type BridgeOptions = {
  bridge_artifact: string
  bridge_address: string
  rpcKey: string
  kappas: Array<string>
  block_number: number
}

describe("Upgradeable", async () => {
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
  let bridgeOptions: BridgeOptions

  // use a stub to return the proper configuration in `beforeEach`
  // otherwise `before` is called all times before all `it` calls
  let stub = sinon.stub()
  chains.forEach(function (run, idx) {
    stub.onCall(idx).returns(run)
  })

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
        bridgeOptions.bridge_address,
        deployer,
        nodeGroup,
      )
    },
  )

  beforeEach(async () => {
    const run = stub()
    bridgeOptions = upgrade[run]
    // fork the chain
    await forkChain(
      process.env[bridgeOptions.rpcKey],
      bridgeOptions.block_number,
    )
    await setupTest()
  })

  chains.forEach(function (run, idx) {
    it(String.Format("Chain {0}: check kappas", run), async () => {
      for (const kappa of bridgeOptions.kappas) {
        expect(await bridge.kappaExists(kappa)).to.be.true
      }
    })
  })
})
