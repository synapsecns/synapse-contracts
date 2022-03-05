//@ts-nocheck
import { Signer } from "ethers"
import { MAX_UINT256, getUserTokenBalance } from "../../../utils"
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
  getAmounts,
  setupAdapterTests,
  prepareAdapterFactories,
  forkChain
} from "../../utils/helpers"

import config from "../../../config.json"
import adapters from "../adapters.json"

chai.use(solidity)
const { expect } = chai

const CHAIN = 1
const DEX = "curve"
const POOL = "basepool"
const ADAPTER = adapters[CHAIN][POOL]
const ADAPTER_NAME = String(ADAPTER.params[0])

describe(ADAPTER_NAME, function () {
  let signers: Array<Signer>

  let owner: Signer
  let ownerAddress: string
  let dude: Signer
  let dudeAddress: string

  let adapter: IAdapter

  let testAdapterSwap: TestAdapterSwap

  // Test Values
  const TOKENS = []

  const TOKENS_DECIMALS: Array<Number> = [18, 6, 6]
  const tokenSymbols: Array<string> = ["DAI", "USDC", "USDT"]

  const ALL_TOKENS: Array<Number> = range(tokenSymbols.length)

  // MAX_SHARE = 1000
  // TODO: ????
  const SHARE_SMALL: Array<Number> = [1, 12, 29, 42]
  const SHARE_BIG: Array<Number> = [66, 121]

  const AMOUNTS: Array<Number> = []
  const AMOUNTS_BIG: Array<Number> = []
  const MAX_UNDERQUOTE: Number = 1
  const CHECK_UNDERQUOTING: Boolean = true

  const MINT_AMOUNT = getBigNumber("1000000000000000000")


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

  before(async function() {
    // 2022-01-13
    await forkChain(process.env.ALCHEMY_API, 14000000)
    console.log(this)
    await prepareAdapterFactories(this, ADAPTER)
  })

  beforeEach(async function() {
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
      config[CHAIN][DEX][POOL],
      tokenSymbols,
      SHARE_SMALL,
    )
    AMOUNTS_BIG = await getAmounts(
      config[CHAIN],
      config[CHAIN][DEX][POOL],
      tokenSymbols,
      SHARE_BIG,
    )
  })

  describe("Sanity checks", () => {
    it("Curve Adapter is properly set up", async function ()  {
      expect(await this.adapter.pool()).to.eq(config[CHAIN][DEX][POOL])

      for (let i in TOKENS) {
        let token = TOKENS[i].address
        expect(await this.adapter.isPoolToken(token))
        expect(await this.adapter.tokenIndex(token)).to.eq(+i)
      }
    })

    it("Swap fails if transfer amount is too little", async function ()  {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let depositAddress = await this.adapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.sub(1))
      await expect(
        this.adapter.swap(
          amount,
          TOKENS[0].address,
          TOKENS[1].address,
          ownerAddress,
        ),
      ).to.be.reverted
    })

    it("Only Owner can rescue overprovided swap tokens", async function ()  {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let extra = getBigNumber(42, TOKENS_DECIMALS[0] - 1)
      let depositAddress = await this.adapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.add(extra))
      await this.adapter.swap(
        amount,
        TOKENS[0].address,
        TOKENS[1].address,
        ownerAddress,
      )

      await expect(
        this.adapter.connect(dude).recoverERC20(TOKENS[0].address, extra),
      ).to.be.revertedWith("Ownable: caller is not the owner")

      await expect(() =>
        this.adapter.recoverERC20(TOKENS[0].address, extra),
      ).to.changeTokenBalance(TOKENS[0], owner, extra)
    })

    it("Anyone can take advantage of overprovided swap tokens", async function ()  {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let extra = getBigNumber(42, TOKENS_DECIMALS[0] - 1)
      let depositAddress = await this.adapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.add(extra))
      await this.adapter.swap(
        amount,
        TOKENS[0].address,
        TOKENS[1].address,
        ownerAddress,
      )

      let swapQuote = await this.adapter.query(
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

    it("Only Owner can rescue GAS from Adapter", async function ()  {
      let amount = 42690
      await expect(() =>
        owner.sendTransaction({
          to: this.adapter.address,
          value: amount,
        }),
      ).to.changeEtherBalance(adapter, amount)

      await expect(this.adapter.connect(dude).recoverGAS(amount)).to.be.revertedWith(
        "Ownable: caller is not the owner",
      )

      await expect(() => this.adapter.recoverGAS(amount)).to.changeEtherBalances(
        [adapter, owner],
        [-amount, amount],
      )
    })
  })

  describe("Adapter Swaps", function () {
    it(
      "Swaps between tokens [" + "{numberOfRuns}" + " small-medium swaps]",
      async function () {
        await testRunAdapter(
          this,
          ALL_TOKENS,
          ALL_TOKENS,
          1, // runs set to 1 right now
          AMOUNTS,
          CHECK_UNDERQUOTING,
        )
      },
    )

    it("Swaps between tokens [90 big-ass swaps]", async function() {
      // await testAdapter(adapter, ALL_TOKENS, ALL_TOKENS, 5, AMOUNTS_BIG)
        await testRunAdapter(
          this,
          ALL_TOKENS,
          ALL_TOKENS,
          1, // runs set to 1 right now
          AMOUNTS_BIG,
          CHECK_UNDERQUOTING,
        )
    })
  })
})
