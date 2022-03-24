//@ts-nocheck
import { Signer } from "ethers"
import { MAX_UINT256, getUserTokenBalance } from "../../../test/utils"
import { solidity } from "ethereum-waffle"
import { deployments } from "hardhat"

import { TestUniswapAdapter } from "../build/typechain/TestUniswapAdapter"
import { GenericERC20 } from "../../../build/typechain/GenericERC20"
import { IERC20Decimals } from "../../../build/typechain/IERC20Decimals"

import chai from "chai"
import { getBigNumber } from "../../../test/bridge/utilities"
import { forkChain, setBalance } from "../../../test/adapters/utils/helpers"

import config from "../../../test/config.json"

chai.use(solidity)
const { expect } = chai

describe("Pangolin Adapter", async function () {
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
  const DEX = "pangolin"
  const FEE = 30 // 0.3%

  const TOKENS: GenericERC20[] = []
  const TOKENS_DECIMALS = []

  const AMOUNTS = [1, 6, 13, 37]
  const CHECK_UNDERQUOTING = true

  const range = (n) => Array.from({ length: n }, (value, key) => key)

  const tokenSymbols = [
    "WAVAX",
    "USDCe",
    "DAIe",
    "USDTe",
    "WETHe",
    "WBTCe",
    "LINKe",
    "alexarUST",
  ]

  const baseTokens = [0]
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
        for (let amount of amounts) {
          let amountIn = getBigNumber(amount, decimalsFrom)
          for (let j of tokensTo) {
            if (i == j) {
              continue
            }
            let tokenTo = tokens[j]

            let amountOut = await adapter.query(
              amountIn,
              tokenFrom.address,
              tokenTo.address,
            )
            if (amountOut == 0) {
              continue
            }

            let depositAddress = await adapter.depositAddress(
              tokenFrom.address,
              tokenTo.address,
            )
            swapsAmount++
            tokenFrom.transfer(depositAddress, amountIn)
            await adapter.swap(
              amountIn,
              tokenFrom.address,
              tokenTo.address,
              ownerAddress,
            )
          }
        }
      }
    console.log("Swaps: ", swapsAmount)
    // let estimate = await adapter.getGasEstimate()
    // console.log("Gas cost: ", estimate.toString())
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
        160000,
        config[CHAIN][DEX].factory,
        config[CHAIN][DEX].hash,
        FEE,
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

  before(async function () {
    // 2022-01-24
    await forkChain(process.env.AVAX_API, 10000000)
  })

  beforeEach(async function () {
    await setupTest()
  })

  describe("Adapter Swaps from Base tokens", () => {
    it("Swaps and Queries from Base (140 swaps)", async function () {
      await testAdapter(uniswapV2Adapter, baseTokens, allTokens, 5)
    })
  })

  describe("Adapter Swaps to Base tokens", () => {
    it("Swaps and Queries to Base (140 swaps)", async function () {
      await testAdapter(uniswapV2Adapter, allTokens, baseTokens, 5)
    })
  })
})
