//@ts-nocheck
import { Signer } from "ethers"
import { MAX_UINT256, getUserTokenBalance } from "../../../amm/testUtils"
import { solidity } from "ethereum-waffle"
import { deployments } from "hardhat"

import { TestAdapterSwap } from "../../../../build/typechain/TestAdapterSwap"
import { IAdapter } from "../../../../build/typechain/IAdapter"
import chai from "chai"
import { getBigNumber } from "../../../bridge/utilities"
import {
  deployAdapter,
  setupTokens,
  testRunAdapter,
  range,
} from "../../utils/helpers"

import config from "../../../config.json"
import adapters from "../adapters.json"

chai.use(solidity)
const { expect } = chai

const CHAIN = 43114
const DEX = "curve"
const POOL = "aave"
const ADAPTER = adapters[CHAIN][POOL]
const ADAPTER_NAME = String(ADAPTER.params[0])

describe(ADAPTER_NAME, async () => {
  let signers: Array<Signer>

  let owner: Signer
  let ownerAddress: string
  let dude: Signer
  let dudeAddress: string

  let adapter: IAdapter

  let testAdapterSwap: TestAdapterSwap

  // Test Values
  const TOKENS = []

  const TOKENS_DECIMALS = []
  const tokenSymbols = ["DAIe", "USDCe", "USDTe"]

  const ALL_TOKENS = range(tokenSymbols.length)

  const AMOUNTS = [8, 1001, 96420, 1337000]
  const AMOUNTS_BIG = [4500600, 10200300]
  const CHECK_UNDERQUOTING = true

  async function testAdapter(
    adapter: IAdapter,
    tokensFrom: Array<number>,
    tokensTo: Array<number>,
    times = 1,
    amounts = AMOUNTS,
  ) {
    await testRunAdapter(
      testAdapterSwap,
      adapter,
      tokensFrom,
      tokensTo,
      times,
      amounts,
      TOKENS,
      TOKENS_DECIMALS,
      CHECK_UNDERQUOTING,
    )
  }

  const setupTest = deployments.createFixture(
    async ({ deployments, ethers }) => {
      const { get } = deployments
      await deployments.fixture() // ensure you start from a fresh deployments

      // TOKENS.length = 0
      signers = await ethers.getSigners()
      owner = signers[0]
      ownerAddress = await owner.getAddress()
      dude = signers[1]
      dudeAddress = await dude.getAddress()

      const testFactory = await ethers.getContractFactory("TestAdapterSwap")

      // we expect the query to underQuote by 1 at maximum
      testAdapterSwap = (await testFactory.deploy(1)) as TestAdapterSwap

      let amount = getBigNumber(1e12)

      TOKENS_DECIMALS = await setupTokens(
        ownerAddress,
        config[CHAIN],
        tokenSymbols,
        amount,
      )

      for (let symbol of tokenSymbols) {
        let token = await ethers.getContractAt(
          "contracts/amm/SwapCalculator.sol:IERC20Decimals",
          config[CHAIN].assets[symbol],
        )
        TOKENS.push(token)
        expect(await getUserTokenBalance(ownerAddress, token)).to.eq(amount)
        await token.approve(testAdapterSwap.address, MAX_UINT256)
      }

      adapter = await deployAdapter(ADAPTER)
    },
  )

  before(async () => {
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: process.env.AVAX_API,
            blockNumber: 10000000, // 2022-01-24
          },
        },
      ],
    })
  })

  beforeEach(async () => {
    await setupTest()
  })

  describe("Sanity checks", () => {
    it("Curve Adapter is properly set up", async () => {
      expect(await adapter.pool()).to.eq(config[CHAIN][DEX][POOL])

      for (let i in TOKENS) {
        let token = TOKENS[i].address
        expect(await adapter.isPoolToken(token))
        expect(await adapter.tokenIndex(token)).to.eq(+i)
      }
    })

    it("Swap fails if transfer amount is too little", async () => {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let depositAddress = await adapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.sub(1))
      await expect(
        adapter.swap(
          amount,
          TOKENS[0].address,
          TOKENS[1].address,
          ownerAddress,
        ),
      ).to.be.reverted
    })

    it("Only Owner can rescue overprovided swap tokens", async () => {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let extra = getBigNumber(42, TOKENS_DECIMALS[0] - 1)
      let depositAddress = await adapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.add(extra))
      await adapter.swap(
        amount,
        TOKENS[0].address,
        TOKENS[1].address,
        ownerAddress,
      )

      await expect(
        adapter.connect(dude).recoverERC20(TOKENS[0].address, extra),
      ).to.be.revertedWith("Ownable: caller is not the owner")

      await expect(() =>
        adapter.recoverERC20(TOKENS[0].address, extra),
      ).to.changeTokenBalance(TOKENS[0], owner, extra)
    })

    it("Anyone can take advantage of overprovided swap tokens", async () => {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let extra = getBigNumber(42, TOKENS_DECIMALS[0] - 1)
      let depositAddress = await adapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.add(extra))
      await adapter.swap(
        amount,
        TOKENS[0].address,
        TOKENS[1].address,
        ownerAddress,
      )

      let swapQuote = await adapter.query(
        extra,
        TOKENS[0].address,
        TOKENS[1].address,
      )

      // .add(1) to reflect underquoting by 1
      await expect(() =>
        adapter
          .connect(dude)
          .swap(extra, TOKENS[0].address, TOKENS[1].address, dudeAddress),
      ).to.changeTokenBalance(TOKENS[1], dude, swapQuote.add(1))
    })

    it("Only Owner can rescue GAS from Adapter", async () => {
      let amount = 42690
      await expect(() =>
        owner.sendTransaction({
          to: adapter.address,
          value: amount,
        }),
      ).to.changeEtherBalance(adapter, amount)

      await expect(adapter.connect(dude).recoverGAS(amount)).to.be.revertedWith(
        "Ownable: caller is not the owner",
      )

      await expect(() => adapter.recoverGAS(amount)).to.changeEtherBalances(
        [adapter, owner],
        [-amount, amount],
      )
    })
  })

  describe("Adapter Swaps", () => {
    it("Swaps between tokens [120 small-medium swaps]", async () => {
      await testAdapter(adapter, ALL_TOKENS, ALL_TOKENS, 5)
    })

    it("Swaps between tokens [120 big-ass swaps]", async () => {
      await testAdapter(adapter, ALL_TOKENS, ALL_TOKENS, 10, AMOUNTS_BIG)
    })
  })
})
