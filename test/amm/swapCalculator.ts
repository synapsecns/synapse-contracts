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
} from "./testUtils"
import { solidity } from "ethereum-waffle"
import { deployments, ethers } from "hardhat"

import { GenericERC20 } from "../../build/typechain/GenericERC20"
import { LPToken } from "../../build/typechain/LPToken"
import { Swap } from "../../build/typechain/Swap"
import { SwapAddCalculator } from "../../build/typechain/SwapAddCalculator"
import chai from "chai"
import { getBigNumber } from "../bridge/utilities"

chai.use(solidity)
const { expect } = chai

describe("SwapAddCalculator", async () => {
  let signers: Array<Signer>
  let swap: Swap
  let swapAddCalculator: SwapAddCalculator
  let DAI: GenericERC20
  let USDC: GenericERC20
  let USDT: GenericERC20
  let SUSD: GenericERC20
  let swapToken: LPToken
  let owner: Signer
  let ownerAddress: string
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

  async function testAddLiquidity(multipliers: Array<number>) {
    let allEqual = true
    for (let j in multipliers) {
      allEqual = allEqual && multipliers[j] == multipliers[0]
    }

    for (let i in AMOUNTS) {
      let unbalanced = []
      for (let j in multipliers) {
        unbalanced.push(AMOUNTS[i] * multipliers[j])
      }
      for (let j in unbalanced) {
        let depositAmounts = [
          getBigNumber(
            unbalanced[(+j + 0) % unbalanced.length],
            TOKENS_DECIMALS[0],
          ),
          getBigNumber(
            unbalanced[(+j + 1) % unbalanced.length],
            TOKENS_DECIMALS[1],
          ),
          getBigNumber(
            unbalanced[(+j + 2) % unbalanced.length],
            TOKENS_DECIMALS[2],
          ),
          getBigNumber(
            unbalanced[(+j + 3) % unbalanced.length],
            TOKENS_DECIMALS[3],
          ),
        ]

        let quotedDeposit = await swapAddCalculator.calculateAddLiquidity(
          depositAmounts,
        )

        await expect(() =>
          swap.addLiquidity(depositAmounts, 0, MAX_UINT256),
        ).to.changeTokenBalance(swapToken, owner, quotedDeposit)

        if (allEqual) {
          break
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
      SUSD = (await erc20Factory.deploy("SUSD", "SUSD", "18")) as GenericERC20

      TOKENS.push(DAI, USDC, USDT, SUSD)

      // Mint dummy tokens
      await DAI.mint(ownerAddress, getBigNumber(100000, TOKENS_DECIMALS[0]))
      await USDC.mint(ownerAddress, getBigNumber(100000, TOKENS_DECIMALS[1]))
      await USDT.mint(ownerAddress, getBigNumber(100000, TOKENS_DECIMALS[2]))
      await SUSD.mint(ownerAddress, getBigNumber(100000, TOKENS_DECIMALS[3]))

      // Deploy Swap with SwapUtils library
      const swapFactory = await ethers.getContractFactory("Swap", {
        libraries: {
          SwapUtils: (await get("SwapUtils")).address,
          AmplificationUtils: (await get("AmplificationUtils")).address,
        },
      })
      swap = (await swapFactory.deploy()) as Swap

      await swap.initialize(
        [DAI.address, USDC.address, USDT.address, SUSD.address],
        TOKENS_DECIMALS,
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

      await DAI.approve(swap.address, MAX_UINT256)
      await USDC.approve(swap.address, MAX_UINT256)
      await USDT.approve(swap.address, MAX_UINT256)
      await SUSD.approve(swap.address, MAX_UINT256)

      const swapAddCalculatorFactory = await ethers.getContractFactory(
        "SwapAddCalculator",
      )

      swapAddCalculator = (await swapAddCalculatorFactory.deploy(
        swap.address,
      )) as SwapAddCalculator
    },
  )

  beforeEach(async () => {
    await setupTest()
  })

  describe("Setup", () => {
    it("SwapAddCalculator is properly set up", async () => {
      expect(await swapAddCalculator.pool()).to.be.eq(swap.address)
      expect(await swapAddCalculator.lpToken()).to.be.eq(swapToken.address)
      expect(await swapAddCalculator.numTokens()).to.be.eq(TOKENS.length)
      expect(await swapAddCalculator.swapFee()).to.be.eq(SWAP_FEE)
    })
  })

  describe("Adding to empty pool", () => {
    it("Reverts when providing not all tokens into empty pool", async () => {
      let AMOUNTS = [String(1e18), String(1e6), String(1e6), String(1e18)]
      for (let i in AMOUNTS) {
        let depositAmounts = []
        for (let j in AMOUNTS) {
          if (i != j) {
            depositAmounts.push(AMOUNTS[j])
          } else {
            depositAmounts.push("0")
          }
        }
        await expect(
          swapAddCalculator.calculateAddLiquidity(depositAmounts),
        ).to.be.revertedWith("Must supply all tokens in pool")
      }
    })

    it("Returns deposited value when providing all tokens into empty pool", async () => {
      for (let i in AMOUNTS) {
        let total = 4 * AMOUNTS[i]
        let depositAmounts = [
          getBigNumber(AMOUNTS[i], TOKENS_DECIMALS[0]),
          getBigNumber(AMOUNTS[i], TOKENS_DECIMALS[1]),
          getBigNumber(AMOUNTS[i], TOKENS_DECIMALS[2]),
          getBigNumber(AMOUNTS[i], TOKENS_DECIMALS[3]),
        ]
        expect(
          await swapAddCalculator.calculateAddLiquidity(depositAmounts),
        ).to.be.eq(getBigNumber(total))
      }
    })
  })

  describe("Adding to existing pool", () => {
    beforeEach(async () => {
      // Populate the pool with initial liquidity
      await swap.addLiquidity(
        [String(50e18), String(50e6), String(50e6), String(50e18)],
        0,
        MAX_UINT256,
      )

      expect(await swap.getTokenBalance(0)).to.be.eq(String(50e18))
      expect(await swap.getTokenBalance(1)).to.be.eq(String(50e6))
      expect(await swap.getTokenBalance(2)).to.be.eq(String(50e6))
      expect(await swap.getTokenBalance(3)).to.be.eq(String(50e18))
      expect(await getUserTokenBalance(owner, swapToken)).to.be.eq(
        String(200e18),
      )
    })

    it("Reverts when quoting empty deposit", async () => {
      await expect(
        swapAddCalculator.calculateAddLiquidity([0, 0, 0, 0]),
      ).to.be.revertedWith("D should increase")
    })

    it("Returns correct value when depositing all tokens in a balanced way", async () => {
      await testAddLiquidity([1, 1, 1, 1])
    })

    it("Returns correct value when depositing all tokens in unbalanced way", async () => {
      await testAddLiquidity([7, 4, 10, 5])
    })

    it("Returns correct value when depositing 3 tokens", async () => {
      await testAddLiquidity([2, 4, 3, 0])
    })

    it("Returns correct value when depositing 2 tokens", async () => {
      await testAddLiquidity([2, 0, 3, 0])
    })

    it("Returns correct value when depositing 1 token", async () => {
      await testAddLiquidity([1, 0, 0, 0])
    })

    it("updateSwapFee on unchanged swap fee doesn't change anything", async () => {
      await swapAddCalculator.updateSwapFee()
      expect(await swapAddCalculator.swapFee()).to.eq(SWAP_FEE)
    })

    it("New fee is applied after updateSwapFee", async () => {
      const NEW_FEE = 2 * SWAP_FEE
      await swap.setSwapFee(NEW_FEE)
      let depositAmounts = [String(1e18), "0", "0", "0"]
      let oldQuotedDeposit = await swapAddCalculator.calculateAddLiquidity(
        depositAmounts,
      )
      // deposit quote with old fee should be too high
      await expect(
        swap.addLiquidity(depositAmounts, oldQuotedDeposit, MAX_UINT256),
      ).to.be.revertedWith("Couldn't mint min requested")

      // let the calculator know that the fee was updated
      await swapAddCalculator.updateSwapFee()

      let quotedDeposit = await swapAddCalculator.calculateAddLiquidity(
        depositAmounts,
      )

      await expect(() =>
        swap.addLiquidity(depositAmounts, 0, MAX_UINT256),
      ).to.changeTokenBalance(swapToken, owner, quotedDeposit)
    })
  })

  describe("Adding to existing pool with changed swap Fee", () => {
    beforeEach(async () => {
      // Populate the pool with initial liquidity
      await swap.addLiquidity(
        [String(50e18), String(50e6), String(50e6), String(50e18)],
        0,
        MAX_UINT256,
      )

      expect(await swap.getTokenBalance(0)).to.be.eq(String(50e18))
      expect(await swap.getTokenBalance(1)).to.be.eq(String(50e6))
      expect(await swap.getTokenBalance(2)).to.be.eq(String(50e6))
      expect(await swap.getTokenBalance(3)).to.be.eq(String(50e18))
      expect(await getUserTokenBalance(owner, swapToken)).to.be.eq(
        String(200e18),
      )

      const NEW_FEE = 2 * SWAP_FEE
      await swap.setSwapFee(NEW_FEE)
      await swapAddCalculator.updateSwapFee()
      expect(await swapAddCalculator.swapFee()).to.eq(NEW_FEE)
    })

    it("Returns correct value when depositing all tokens in a balanced way", async () => {
      await testAddLiquidity([1, 1, 1, 1])
    })

    it("Returns correct value when depositing all tokens in unbalanced way", async () => {
      await testAddLiquidity([7, 4, 10, 5])
    })

    it("Returns correct value when depositing 3 tokens", async () => {
      await testAddLiquidity([2, 4, 3, 0])
    })

    it("Returns correct value when depositing 2 tokens", async () => {
      await testAddLiquidity([2, 0, 3, 0])
    })

    it("Returns correct value when depositing 1 token", async () => {
      await testAddLiquidity([1, 0, 0, 0])
    })
  })
})
