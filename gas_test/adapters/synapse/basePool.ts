//@ts-nocheck
import { BigNumber, Signer } from "ethers"
import { MAX_UINT256, getUserTokenBalance } from "../../../test/utils"
import { solidity } from "ethereum-waffle"
import { deployments } from "hardhat"

import { TestAdapterSwap } from "../build/typechain/TestAdapterSwap"

import { GenericERC20 } from "../../../build/typechain/GenericERC20"
import { LPToken } from "../../../build/typechain/LPToken"
import { Swap } from "../../../build/typechain/Swap"
import { SynapseBaseAdapter } from "../../../build/typechain/SynapseBaseAdapter"
import chai from "chai"
import { getBigNumber } from "../../../test/bridge/utilities"

chai.use(solidity)
const { expect } = chai

describe("Base Pool Adapter", async function () {
  let signers: Array<Signer>
  let swap: Swap
  let DAI: GenericERC20
  let USDC: GenericERC20
  let USDT: GenericERC20

  let swapToken: LPToken
  let owner: Signer
  let ownerAddress: string
  let dude: Signer
  let dudeAddress: string

  let baseAdapter: SynapseBaseAdapter

  let testAdapterSwap: TestAdapterSwap

  let swapStorage: {
    initialA: BigNumber
    futureA: BigNumber
    initialATime: BigNumber
    futureATime: BigNumber
    swapFee: BigNumber
    adminFee: BigNumber
    lpToken: string
  }

  // Test Values
  const INITIAL_A_VALUE = 50
  const SWAP_FEE = 1e7
  const LP_TOKEN_NAME = "Test LP Token Name"
  const LP_TOKEN_SYMBOL = "TESTLP"
  const TOKENS: GenericERC20[] = []
  const TOKENS_DECIMALS = [18, 6, 6, 18]

  const AMOUNTS = [2, 6, 15, 49]
  const AMOUNTS_BIG = [123, 404, 777]
  const CHECK_UNDERQUOTING = true

  async function testAdapter(
    adapter: SynapseBaseAdapter,
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
      await deployments.fixture() // ensure you start from a fresh deployments

      TOKENS.length = 0
      signers = await ethers.getSigners()
      owner = signers[0]
      ownerAddress = await owner.getAddress()
      dude = signers[1]
      dudeAddress = await dude.getAddress()

      const testFactory = await ethers.getContractFactory("TestAdapterSwap")
      testAdapterSwap = (await testFactory.deploy(0)) as TestAdapterSwap

      // Deploy dummy tokens
      const erc20Factory = await ethers.getContractFactory("GenericERC20")

      DAI = (await erc20Factory.deploy("DAI", "DAI", "18")) as GenericERC20
      USDC = (await erc20Factory.deploy("USDC", "USDC", "6")) as GenericERC20
      USDT = (await erc20Factory.deploy("USDT", "USDT", "6")) as GenericERC20

      // Mint dummy tokens
      await DAI.mint(ownerAddress, getBigNumber(100000, TOKENS_DECIMALS[0]))
      await USDC.mint(ownerAddress, getBigNumber(100000, TOKENS_DECIMALS[1]))
      await USDT.mint(ownerAddress, getBigNumber(100000, TOKENS_DECIMALS[2]))

      // Deploy Swap with SwapUtils library
      const swapFactory = await ethers.getContractFactory("Swap", {
        libraries: {
          SwapUtils: (await get("SwapUtils")).address,
          AmplificationUtils: (await get("AmplificationUtils")).address,
        },
      })
      swap = (await swapFactory.deploy()) as Swap

      await swap.initialize(
        [DAI.address, USDC.address, USDT.address],
        [18, 6, 6],
        LP_TOKEN_NAME,
        LP_TOKEN_SYMBOL,
        INITIAL_A_VALUE,
        SWAP_FEE,
        0,
        (
          await get("LPToken")
        ).address,
      )

      expect(await swap.getVirtualPrice()).to.be.eq(0)

      swapStorage = await swap.swapStorage()

      swapToken = (await ethers.getContractAt(
        "LPToken",
        swapStorage.lpToken,
      )) as LPToken

      TOKENS.push(DAI, USDC, USDT, swapToken)

      for (let token of TOKENS) {
        await token.approve(swap.address, MAX_UINT256)
        await token.approve(testAdapterSwap.address, MAX_UINT256)
      }

      const baseAdapterFactory = await ethers.getContractFactory(
        "SynapseBaseAdapter",
      )

      baseAdapter = (await baseAdapterFactory.deploy(
        "BasePoolAdapter",
        160000,
        swap.address,
      )) as SynapseBaseAdapter

      let amounts = [
        getBigNumber(2000, TOKENS_DECIMALS[0]),
        getBigNumber(2000, TOKENS_DECIMALS[1]),
        getBigNumber(2000, TOKENS_DECIMALS[2]),
      ]

      // Populate the pool with initial liquidity
      await swap.addLiquidity(amounts, 0, MAX_UINT256)

      for (let i in amounts) {
        expect(await swap.getTokenBalance(i)).to.be.eq(amounts[i])
      }

      expect(await getUserTokenBalance(owner, swapToken)).to.be.eq(
        getBigNumber(6000),
      )
    },
  )

  beforeEach(async function () {
    await setupTest()
  })

  describe("Adapter Swaps", () => {
    it("Swaps between tokens [48 small-medium sized swaps]", async function () {
      await testAdapter(baseAdapter, [0, 1, 2], [0, 1, 2], 5)
    })

    // it("Withdraw from LP token [120 small-medium sized swaps]", async function() {
    //   await testAdapter(baseAdapter, [3], [0, 1, 2], 10)
    // })
  })
})
