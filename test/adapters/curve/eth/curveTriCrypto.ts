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
  range, forkChain, prepareAdapterFactories, setupAdapterTests, getAmounts,
} from "../../utils/helpers"

import config from "../../../config.json"
import adapters from "../adapters.json"
import {CurveBasePoolAdapter} from "../../../../build/typechain";

chai.use(solidity)


const { expect } = chai
const CHAIN = 1

const DEX = "curve"
const POOL = "tricrypto"
const STORAGE = "tricrypto"
const ADAPTER = adapters[CHAIN][POOL]
const ADAPTER_NAME = String(ADAPTER.params[0])

describe.only(ADAPTER_NAME, async () => {
  let signers: Array<Signer>

  let owner: Signer
  let ownerAddress: string
  let dude: Signer
  let dudeAddress: string

  let adapter: CurveBasePoolAdapter

  let testAdapterSwap: TestAdapterSwap

  const TOKENS_DECIMALS = []
  const TOKENS = []
  // const TOKENS_DECIMALS: Array<Number> = [6, 4, 14]
  const poolTokenSymbols: Array<String> = ["USDT", "WBTC", "WETH"]

  const ALL_TOKENS: Array<Number> = range(poolTokenSymbols.length)

  const SHARE_SMALL: Array<Number> = [1, 12, 29, 42]
  const SHARE_BIG: Array<Number> = [66, 121]

  const AMOUNTS: Array<Number> = []
  const AMOUNTS_BIG: Array<Number> =  []

  const CHECK_UNDERQUOTING = true
  const MAX_UNDERQUOTE = 1
  const MINT_AMOUNT = getBigNumber("1000000000000000000")


  before(async function () {
    await forkChain(process.env.ALCHEMY_API, 14000000)
    await prepareAdapterFactories(this, ADAPTER)
  })

  beforeEach(async function ()  {
    await setupAdapterTests(
        this,
        config[CHAIN],
        ADAPTER,
        poolTokenSymbols,
        MAX_UNDERQUOTE,
        MINT_AMOUNT
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

    adapter = this.adapter
    TOKENS = this.tokens
    TOKENS_DECIMALS = this.tokenDecimals
    owner = this.owner
    dude = this.dude
    ownerAddress = this.ownerAddress
    dudeAddress = this.dudeAddress
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
    it("Swaps between tokens [120 small-medium swaps]", async function() {
      await testRunAdapter(
          this,
          ALL_TOKENS,
          ALL_TOKENS,
          5,
          AMOUNTS,
          CHECK_UNDERQUOTING,
      )
    })

    it("Swaps between tokens [90 big-ass swaps]", async function() {
      await testRunAdapter(
          this,
          ALL_TOKENS,
          ALL_TOKENS,
          5,
          AMOUNTS_BIG,
          CHECK_UNDERQUOTING,
      )
    })
  })
})
