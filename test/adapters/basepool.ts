//@ts-nocheck
import { BigNumber, Signer } from "ethers"
import {
  MAX_UINT256,
  TIME,
  asyncForEach,
  getCurrentBlockTimestamp,
  getPoolBalances,
  getUserTokenBalance,
  getUserTokenBalances,
  setTimestamp,
} from "../amm/testUtils"
import { solidity } from "ethereum-waffle"
import { deployments, ethers } from "hardhat"

import { GenericERC20 } from "../../build/typechain/GenericERC20"
import { LPToken } from "../../build/typechain/LPToken"
import { Swap } from "../../build/typechain/Swap"
import { Adapter } from "../../build/typechain/Adapter"
import { SynapseBasePoolAdapter } from "../../build/typechain/SynapseBasePoolAdapter"
import chai from "chai"
import { getBigNumber } from "../bridge/utilities"

chai.use(solidity)
const { expect } = chai

describe("Base Pool Adapter", async () => {
  let signers: Array<Signer>
  let swap: Swap
  let DAI: GenericERC20
  let USDC: GenericERC20
  let USDT: GenericERC20

  let swapToken: LPToken
  let owner: Signer
  let ownerAddress: string

  let basePoolAdapter: SynapseBasePoolAdapter

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
  const AMOUNTS = [5, 42, 96]

  async function testAdapter(
    adapter: Adapter,
    tokensFrom: Array<number>,
    tokensTo: Array<number>,
  ) {
    for (let i in tokensFrom) {
      let tokenFrom = TOKENS[tokensFrom[i]]
      let decimalsFrom = TOKENS_DECIMALS[tokensFrom[i]]
      for (let j in tokensTo) {
        let tokenTo = TOKENS[tokensTo[j]]
        let depositAddress = await adapter.depositAddress(
          tokenFrom.address,
          tokenTo.address,
        )
        for (let k in AMOUNTS) {
          let amount = getBigNumber(AMOUNTS[k], decimalsFrom)
          await tokenFrom.transfer(depositAddress, amount)
          let swapQuote = await adapter.query(
            amount,
            tokenFrom.address,
            tokenTo.address,
          )
          let balanceBefore = await getUserTokenBalance(owner, tokenTo)
          let swappedAmount = adapter.swap(
            amount,
            tokenFrom.address,
            tokenTo.address,
          )
          expect(swappedAmount).to.eq(swapQuote)
          expect(await getUserTokenBalance(owner, tokenTo)).to.eq(
            balanceBefore.add(swapQuote),
          )
        }
      }
    }
  }

  const setupTest = deployments.createFixture(
    async ({ deployments, ethers }) => {
      const { get } = deployments
      await deployments.fixture() // ensure you start from a fresh deployments

      TOKENS.length = 0
      signers = await ethers.getSigners()
      owner = signers[0]
      ownerAddress = await owner.getAddress()

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

      await DAI.approve(swap.address, MAX_UINT256)
      await USDC.approve(swap.address, MAX_UINT256)
      await USDT.approve(swap.address, MAX_UINT256)
      await swapToken.approve(swap.address, MAX_UINT256)

      const basePoolAdapterFactory = await ethers.getContractFactory(
        "SynapseBasePoolAdapter",
      )

      basePoolAdapter = (await basePoolAdapterFactory.deploy(
        "BasePoolAdapter",
        swap.address,
        160000,
      )) as SynapseBasePoolAdapter

      let amounts = [
        getBigNumber(500, TOKENS_DECIMALS[0]),
        getBigNumber(500, TOKENS_DECIMALS[1]),
        getBigNumber(500, TOKENS_DECIMALS[2]),
      ]

      // Populate the pool with initial liquidity
      await swap.addLiquidity(amounts, 0, MAX_UINT256)

      for (let i in amounts) {
        expect(await swap.getTokenBalance(i)).to.be.eq(amounts[i])
      }

      expect(await getUserTokenBalance(owner, swapToken)).to.be.eq(
        getBigNumber(1500),
      )
    },
  )

  beforeEach(async () => {
    await setupTest()
  })

  describe("Setup", () => {
    it("BasePool Adapter is properly set up", async () => {
      expect(await basePoolAdapter.pool()).to.be.eq(swap.address)
      expect(await basePoolAdapter.lpToken()).to.be.eq(swapToken.address)
      expect(await basePoolAdapter.numTokens()).to.be.eq(TOKENS.length - 1)
      expect(await basePoolAdapter.swapFee()).to.be.eq(SWAP_FEE)

      for (let i in TOKENS) {
        expect(await basePoolAdapter.isPoolToken(TOKENS[i].address))
        expect(await basePoolAdapter.tokenIndex(TOKENS[i].address)).to.eq(+i)
      }
    })
  })
})
