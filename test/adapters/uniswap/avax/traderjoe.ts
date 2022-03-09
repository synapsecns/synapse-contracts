//@ts-nocheck
import { Signer } from "ethers"
import { MAX_UINT256, getUserTokenBalance } from "../../../utils"
import { solidity } from "ethereum-waffle"
import { deployments } from "hardhat"

import { TestUniswapAdapter } from "../build/typechain/TestUniswapAdapter"
import { GenericERC20 } from "../../../../build/typechain/GenericERC20"
import { IERC20Decimals } from "../../../../build/typechain/IERC20Decimals"
import { IWETH9 } from "../../../../build/typechain/IWETH9"

import chai from "chai"
import { getBigNumber } from "../../../bridge/utilities"
import {forkChain, setBalance} from "../../utils/helpers"

import config from "../../../config.json"

chai.use(solidity)
const { expect } = chai

describe("TraderJoe Adapter", async function() {
  let signers: Array<Signer>

  let owner: Signer
  let ownerAddress: string
  let dude: Signer
  let dudeAddress: string

  let uniswapV2Adapter: UniswapV2Adapter

  let testAdapterSwap: TestUniswapAdapter

  let baseTokens: Array<number>
  let allTokens: Array<number>

  const CHAIN = 43114
  const DEX = "traderjoe"
  const FEE = 30 // 0.3%

  const TOKENS: GenericERC20[] = []
  const TOKENS_DECIMALS = []

  const AMOUNTS = [1, 13, 96]
  const CHECK_UNDERQUOTING = true

  const range = n => Array.from({length: n}, (value, key) => key)

  const tokenSymbols = [
    "WAVAX",
    "USDCe",
    "WETHe",
    "WBTCe",
    "LINKe",
    "JOE"
  ]

  const baseTokens = [0, 1]
  const allTokens = range(tokenSymbols.length)

  async function testAdapter(
    adapter: UniswapV2Adapter,
    tokensFrom: Array<number>,
    tokensTo: Array<number>,
    times = 1,
    amounts = AMOUNTS,
    tokens = TOKENS,
    decimals = TOKENS_DECIMALS,
  ) {
    let swapsAmount = 0
    for (var k = 0; k < times; k++)
      for (let i of tokensFrom) {
        let tokenFrom = tokens[i]
        let decimalsFrom = decimals[i]
        for (let j of tokensTo) {
          if (i == j) {
            continue
          }
          let tokenTo = tokens[j]
          for (let amount of amounts) {
            swapsAmount++
            await testAdapterSwap.testSwap(
              adapter.address,
              getBigNumber(amount, decimalsFrom),
              tokenFrom.address,
              tokenTo.address,
              CHECK_UNDERQUOTING,
              swapsAmount,
            )
          }
        }
      }
  }

  const setupTest = deployments.createFixture(
    async ({ deployments, ethers }) => {
      const { get } = deployments
      await deployments.fixture() // ensure you start froeqm a fresh deployments

      TOKENS.length = 0
      signers = await ethers.getSigners()
      owner = signers[0]
      ownerAddress = await owner.getAddress()
      dude = signers[1]
      dudeAddress = await dude.getAddress()

      const uniswapAdapterFactory = await ethers.getContractFactory(
        "UniswapV2Adapter",
      )

      uniswapV2Adapter = (await uniswapAdapterFactory.deploy(
        "UniswapV2Adapter",
        config[CHAIN][DEX].factory,
        160000,
        FEE
      )) as UniswapV2Adapter

      const testFactory = await ethers.getContractFactory("TestUniswapAdapter")

      testAdapterSwap = (await testFactory.deploy(
        config[CHAIN][DEX].router,
      )) as TestUniswapAdapter

      for (let symbol of tokenSymbols) {
        let tokenAddress = config[CHAIN].assets[symbol]
        let storageSlot = config[CHAIN].slot[symbol]
        let token = (await ethers.getContractAt(
          "contracts/router/helper/SwapCalculator.sol:IERC20Decimals",
          tokenAddress,
        )) as IERC20Decimals
        TOKENS.push(token)
        let decimals = await token.decimals()
        TOKENS_DECIMALS.push(decimals)
        let amount = getBigNumber(5000, decimals)
        await setBalance(ownerAddress, tokenAddress, amount, storageSlot)
        expect(await getUserTokenBalance(owner, token)).to.be.eq(amount)

        token.approve(testAdapterSwap.address, MAX_UINT256)
      }
    },
  )

  before(async function() {
    // 2022-01-24
    await forkChain(process.env.AVAX_API, 10000000)
  })

  beforeEach(async function() {
    await setupTest()
  })

  describe("Sanity checks", () => {
    it("UniswapV2 Adapter is properly set up", async function() {
      expect(await uniswapV2Adapter.uniswapV2Factory()).to.eq(
        config[CHAIN][DEX].factory,
      )
    })

    it("Swap fails when there is no direct path between tokens", async function() {
      // WETHe -> LINKe
      let tokenFrom = 2
      let tokenTo = 4
      let amount = getBigNumber(10, TOKENS_DECIMALS[tokenFrom])

      expect(
        await uniswapV2Adapter.query(
          amount,
          TOKENS[tokenFrom].address,
          TOKENS[tokenTo].address,
        ),
      ).to.eq(0)

      await expect(
        uniswapV2Adapter.swap(
          amount,
          TOKENS[tokenFrom].address,
          TOKENS[tokenTo].address,
          ownerAddress,
        ),
      ).to.be.revertedWith("Swap pool does not exist")
    })

    it("Swap fails if transfer amount is too little", async function() {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let depositAddress = await uniswapV2Adapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      const BASE = 1000000
      TOKENS[0].transfer(depositAddress, amount.mul(BASE - 1).div(BASE))
      await expect(
        uniswapV2Adapter.swap(
          amount,
          TOKENS[0].address,
          TOKENS[1].address,
          ownerAddress,
        ),
      ).to.be.reverted
    })

    it("Noone can rescue overprovided swap tokens", async function() {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let extra = getBigNumber(42, TOKENS_DECIMALS[0] - 1)
      let depositAddress = await uniswapV2Adapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.add(extra))
      await uniswapV2Adapter.swap(
        amount,
        TOKENS[0].address,
        TOKENS[1].address,
        ownerAddress,
      )

      await expect(
        uniswapV2Adapter.connect(dude).recoverERC20(TOKENS[0].address, extra),
      ).to.be.revertedWith("Ownable: caller is not the owner")

      // tokens are in the UniSwap pair, not the Adapter
      await expect(uniswapV2Adapter.recoverERC20(TOKENS[0].address, extra)).to.be
        .reverted
    })

    it("Noone can take advantage of overprovided swap tokens", async function() {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let extra = getBigNumber(42, TOKENS_DECIMALS[0] - 1)
      let depositAddress = await uniswapV2Adapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.add(extra))
      await uniswapV2Adapter.swap(
        amount,
        TOKENS[0].address,
        TOKENS[1].address,
        ownerAddress,
      )

      // UniSwap reserves are updated at the end of swap
      // https://github.com/Uniswap/v2-core/blob/4dd59067c76dea4a0e8e4bfdda41877a6b16dedc/contracts/UniswapV2Pair.sol#L185
      await expect(
        uniswapV2Adapter
          .connect(dude)
          .swap(extra, TOKENS[0].address, TOKENS[1].address, dudeAddress),
      ).to.be.reverted
    })

    it("Only Owner can rescue tokens sent to Adapter", async function() {
      let extra = getBigNumber(10, TOKENS_DECIMALS[0])
      await TOKENS[0].transfer(uniswapV2Adapter.address, extra)

      await expect(
        uniswapV2Adapter.connect(dude).recoverERC20(TOKENS[0].address, extra),
      ).to.be.revertedWith("Ownable: caller is not the owner")

      await expect(() =>
        uniswapV2Adapter.recoverERC20(TOKENS[0].address, extra),
      ).to.changeTokenBalance(TOKENS[0], owner, extra)
    })

    it("Only Owner can rescue GAS from Adapter", async function() {
      let amount = 42690
      await expect(() =>
        owner.sendTransaction({ to: uniswapV2Adapter.address, value: amount }),
      ).to.changeEtherBalance(uniswapV2Adapter, amount)

      await expect(
        uniswapV2Adapter.connect(dude).recoverGAS(amount),
      ).to.be.revertedWith("Ownable: caller is not the owner")

      await expect(() =>
        uniswapV2Adapter.recoverGAS(amount),
      ).to.changeEtherBalances([uniswapV2Adapter, owner], [-amount, amount])
    })
  })

  describe("Adapter Swaps from Base tokens", () => {
    it("Swaps and Queries from Base (150 swaps)", async function() {
      await testAdapter(uniswapV2Adapter, baseTokens, allTokens, 5)
    })
  })

  describe("Adapter Swaps to Base tokens", () => {
    it("Swaps and Queries to Base (150 swaps)", async function() {
      await testAdapter(uniswapV2Adapter, allTokens, baseTokens, 5)
    })
  })
})
