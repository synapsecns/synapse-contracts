//@ts-nocheck
import chai from "chai"
import { solidity } from "ethereum-waffle"

import { getUserTokenBalance } from "../../../utils"
import { getBigNumber } from "../../../bridge/utilities"
import {
  testRunAdapter,
  range,
  prepareAdapterFactories,
  setupAdapterTests,
  forkChain,
  getAmounts,
  getSwapsAmount,
  doSwap,
} from "../../utils/helpers"

import config from "../../../config.json"
import adapters from "../../adapters.json"

chai.use(solidity)
const { expect } = chai

const CHAIN = 43114
const DEX = "curve"
const POOL = "usdc"
const STORAGE = "usdc"
const ADAPTER = adapters[CHAIN][DEX][POOL]
const ADAPTER_NAME = String(ADAPTER.params[0])

describe(ADAPTER_NAME, function () {
  let timesBig: Number
  let swapsAmountBig: Number

  const tokenSymbols = ["USDCe", "USDC"]
  const poolTokenSymbols = ["USDCe", "USDC"]

  const ALL_TOKENS = range(tokenSymbols.length)

  // MAX_SHARE = 1000
  const SHARE_SMALL = [1, 12, 29, 42]
  const SHARE_BIG = [66, 121]

  let swapsPerTime = SHARE_SMALL.length * getSwapsAmount(tokenSymbols.length)
  const timesSmall = Math.floor(40 / swapsPerTime) + 1
  const swapsAmount = timesSmall * swapsPerTime

  swapsPerTime = SHARE_BIG.length * getSwapsAmount(tokenSymbols.length)
  const timesBig = Math.floor(30 / swapsPerTime) + 1
  const swapsAmountBig = timesBig * swapsPerTime

  const AMOUNTS = []
  const AMOUNTS_BIG = []

  const MAX_UNDERQUOTE = 1
  const CHECK_UNDERQUOTING = true

  const MINT_AMOUNT = getBigNumber("1000000000000000000")

  before(async function () {
    // 2022-01-24
    await forkChain(process.env.AVAX_API, 10000000)
    await prepareAdapterFactories(this, ADAPTER)
  })

  beforeEach(async function () {
    await setupAdapterTests(
      this,
      config[CHAIN],
      ADAPTER,
      tokenSymbols,
      MAX_UNDERQUOTE,
      MINT_AMOUNT,
    )

    for (let token of this.tokens) {
      expect(await getUserTokenBalance(this.ownerAddress, token)).to.eq(
        MINT_AMOUNT,
      )
    }

    AMOUNTS = await getAmounts(
      config[CHAIN],
      config[CHAIN][DEX][STORAGE],
      poolTokenSymbols,
      SHARE_SMALL,
    )
    AMOUNTS_BIG = await getAmounts(
      config[CHAIN],
      config[CHAIN][DEX][STORAGE],
      poolTokenSymbols,
      SHARE_BIG,
    )
  })

  describe("Sanity checks", function () {
    it("Curve Adapter is properly set up", async function () {
      expect(await this.adapter.pool()).to.eq(config[CHAIN][DEX][POOL])

      for (let i in this.tokens) {
        let token = this.tokens[i].address
        expect(await this.adapter.isPoolToken(token))
        expect(await this.adapter.tokenIndex(token)).to.eq(+i)
      }
    })

    it("Swap fails if transfer amount is too little", async function () {
      let indexFrom = 0
      let indexTo = 1
      let amount = getBigNumber(10, this.tokenDecimals[indexFrom])
      await expect(doSwap(this, amount, indexFrom, indexTo, -1)).to.be.reverted
    })

    it("Only Owner can rescue overprovided swap tokens", async function () {
      let indexFrom = 0
      let indexTo = 1
      let amount = getBigNumber(10, this.tokenDecimals[indexFrom])
      let extra = getBigNumber(42, this.tokenDecimals[indexFrom] - 1)
      await doSwap(this, amount, indexFrom, indexTo, extra)

      await expect(
        this.adapter
          .connect(this.dude)
          .recoverERC20(this.tokens[indexFrom].address),
      ).to.be.revertedWith("Ownable: caller is not the owner")

      await expect(() =>
        this.adapter.recoverERC20(this.tokens[indexFrom].address),
      ).to.changeTokenBalance(this.tokens[indexFrom], this.owner, extra)
    })

    it("Anyone can take advantage of overprovided swap tokens", async function () {
      let indexFrom = 0
      let indexTo = 1
      let amount = getBigNumber(10, this.tokenDecimals[indexFrom])
      let extra = getBigNumber(42, this.tokenDecimals[indexFrom] - 1)
      await doSwap(this, amount, indexFrom, indexTo, extra)

      let swapQuote = await this.adapter.query(
        extra,
        this.tokens[indexFrom].address,
        this.tokens[indexTo].address,
      )

      // .add(MAX_UNDERQUOTE) to reflect underquoting
      await expect(() =>
        doSwap(this, extra, indexFrom, indexTo, 0, "dude", false),
      ).to.changeTokenBalance(
        this.tokens[indexTo],
        this.dude,
        swapQuote.add(MAX_UNDERQUOTE),
      )
    })

    it("Only Owner can rescue GAS from Adapter", async function () {
      let amount = 42690
      await expect(() =>
        this.owner.sendTransaction({
          to: this.adapter.address,
          value: amount,
        }),
      ).to.changeEtherBalance(this.adapter, amount)

      await expect(
        this.adapter.connect(this.dude).recoverGAS(),
      ).to.be.revertedWith("Ownable: caller is not the owner")

      await expect(() => this.adapter.recoverGAS()).to.changeEtherBalances(
        [this.adapter, this.owner],
        [-amount, amount],
      )
    })
  })

  describe("Adapter Swaps", function () {
    it(
      "Swaps between tokens [" + swapsAmount + " small-medium swaps]",
      async function () {
        await testRunAdapter(
          this,
          ALL_TOKENS,
          ALL_TOKENS,
          timesSmall,
          AMOUNTS,
          CHECK_UNDERQUOTING,
        )
      },
    )

    it(
      "Swaps between tokens [" + swapsAmountBig + " big-ass swaps]",
      async function () {
        await testRunAdapter(
          this,
          ALL_TOKENS,
          ALL_TOKENS,
          timesBig,
          AMOUNTS_BIG,
          CHECK_UNDERQUOTING,
        )
      },
    )
  })
})
