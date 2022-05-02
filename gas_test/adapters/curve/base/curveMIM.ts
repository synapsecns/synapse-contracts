//@ts-nocheck
import chai from "chai"
import { solidity } from "ethereum-waffle"

import { getUserTokenBalance } from "../../../../test/utils"
import { getBigNumber } from "../../../../test/bridge/utilities"
import {
  testRunAdapter,
  range,
  prepareAdapterFactories,
  setupAdapterTests,
  forkChain,
  getAmounts,
  getSwapsAmount,
  doSwap,
} from "../../../../test/adapters/utils/helpers"

import config from "../../../../test/config.json"
import adapters from "../../../../test/adapters/curve/adapters.json"
import { Context } from "mocha"

chai.use(solidity)
const { expect } = chai

const CHAIN = 43114
const DEX = "curve"
const POOL = "mim"
const STORAGE = "mim"
const ADAPTER = adapters[CHAIN][POOL]
const ADAPTER_NAME = String(ADAPTER.params[0])

describe(ADAPTER_NAME, function () {
  let timesBig: Number
  let swapsAmountBig: Number

  const tokenSymbols = ["MIM", "USDTe", "USDCe"]
  const poolTokenSymbols = ["MIM", "USDTe", "USDCe"]

  const ALL_TOKENS = range(tokenSymbols.length)

  // MAX_SHARE = 1000
  const SHARE_SMALL = [1, 12, 29, 42]
  const SHARE_BIG = [66, 121]

  let swapsPerTime = SHARE_SMALL.length * getSwapsAmount(tokenSymbols.length)
  const timesSmall = Math.floor(100 / swapsPerTime) + 1
  const swapsAmount = timesSmall * swapsPerTime

  const AMOUNTS = []

  const MAX_UNDERQUOTE = 1
  const CHECK_UNDERQUOTING = true

  const MINT_AMOUNT = getBigNumber("1000000000000000000")

  async function testAdapter(
    thisObject: Context,
    tokensFrom: Array<number>,
    tokensTo: Array<number>,
    times = 1,
    amounts = AMOUNTS,
  ) {
    let swapsAmount = 0
    let amountNum = amounts[0].length
    let tokens = thisObject.tokens
    let adapter = thisObject.adapter

    for (let _iter in range(times))
      for (let indexAmount in range(amountNum))
        for (let indexTo of tokensTo) {
          let tokenTo = tokens[indexTo]
          for (let indexFrom of tokensFrom) {
            if (indexFrom == indexTo) {
              continue
            }

            let tokenFrom = tokens[indexFrom]

            let depositAddress = await adapter.depositAddress(
              tokenFrom.address,
              tokenTo.address,
            )
            swapsAmount++
            tokenFrom.transfer(depositAddress, amounts[indexFrom][indexAmount])
            await adapter.swap(
              amounts[indexFrom][indexAmount],
              tokenFrom.address,
              tokenTo.address,
              thisObject.ownerAddress,
            )
          }
        }
    console.log("Swaps: %s", swapsAmount)
  }

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
  })

  describe("Adapter Swaps", function () {
    it(
      "Swaps between tokens [" + swapsAmount + " small-medium swaps]",
      async function () {
        await testAdapter(this, ALL_TOKENS, ALL_TOKENS, timesSmall, AMOUNTS)
      },
    )
  })
})
