import { expect } from "chai"
import { web3, deployments, network } from "hardhat"
import { solidity } from "ethereum-waffle"
import {
  prepare,
  deploy,
  getBigNumber,
  setupSynapsePool,
  setupUniswapAdapters,
  setupUniswapPool,
} from "./utils"
import { Router } from "../../build/typechain/Router"

import chai from "chai"
import { ContractFactory, Signer } from "ethers"
import { MAX_UINT256, ZERO_ADDRESS } from "../utils"
import { Adapter, BasicQuoter, WETH9 } from "../../build/typechain"
import { Context } from "mocha"

chai.use(solidity)

describe("Router", function () {
  let router: Router
  let quoter: BasicQuoter

  const ADAPTERS_STORAGE_ROLE = web3.utils.keccak256("ADAPTERS_STORAGE_ROLE")

  let owner: Signer
  let ownerAddress: string

  let dude: Signer
  let dudeAddress: string

  let signers: Array<Signer>

  let weth: WETH9

  let swapFactory: ContractFactory
  let lpTokenAddress: string

  let adapters: Array<Adapter>

  const synUSD = 0
  const synETH = 1
  const uniAAA = 2
  const uniBBB = 3
  const uniCCC = 4

  const decimals = {
    syn: 18,
    neth: 18,
    weth: 18,
    dai: 18,
    usdc: 6,
    usdt: 6,
    gmx: 18,
    ohm: 9,
    wbtc: 8,
  }

  const seededLiquidity = {
    aaaSwapFactory: [
      {
        tokenA: "weth",
        tokenB: "wbtc",
        amountA: 10,
        amountB: 1,
      },
      {
        tokenA: "weth",
        tokenB: "usdt",
        amountA: 1,
        amountB: 10,
      },
      {
        tokenA: "gmx",
        tokenB: "usdc",
        amountA: 40,
        amountB: 60,
      },
      {
        tokenA: "neth",
        tokenB: "ohm",
        amountA: 20,
        amountB: 420,
      },
    ],
    bbbSwapFactory: [
      {
        tokenA: "wbtc",
        tokenB: "usdc",
        amountA: 1,
        amountB: 100,
      },
      {
        tokenA: "weth",
        tokenB: "dai",
        amountA: 10,
        amountB: 90,
      },
      {
        tokenA: "neth",
        tokenB: "usdt",
        amountA: 2,
        amountB: 15,
      },
      {
        tokenA: "wbtc",
        tokenB: "usdt",
        amountA: 2,
        amountB: 180,
      },
    ],
    cccSwapFactory: [
      {
        tokenA: "dai",
        tokenB: "usdc",
        amountA: 100,
        amountB: 120,
      },
      {
        tokenA: "wbtc",
        tokenB: "weth",
        amountA: 10,
        amountB: 80,
      },
      {
        tokenA: "neth",
        tokenB: "syn",
        amountA: 10,
        amountB: 13,
      },
    ],
  }

  async function checkRouterSwap(
    thisObject: Context,
    tokenNames: Array<string>,
    adapterIndexes: Array<number>,
    amount: number = 1,
  ) {
    let tokenInName = tokenNames[0]
    let amountIn = getBigNumber(amount, decimals[tokenInName])
    let amountOut = amountIn

    let tokenPath = tokenNames.map(function (tokenName) {
      return thisObject[tokenName].address
    })

    let adapterPath = adapterIndexes.map(function (adapterIndex) {
      return adapters[adapterIndex]
    })

    let adapterAddresses = adapterPath.map(function (adapter) {
      return adapter.address
    })

    for (let index in adapterIndexes) {
      let adapter = adapterPath[index]
      amountOut = await adapter.query(
        amountOut,
        tokenPath[index],
        tokenPath[+index + 1],
      )
    }

    let tokenOutName = tokenNames[tokenNames.length - 1]

    if (tokenInName == tokenOutName) {
      amountOut = amountOut.sub(amountIn)
    }

    let tokenOut = thisObject[tokenOutName]
    if (tokenOutName == "weth") {
      await expect(() =>
        router.swapToGAS(
          amountIn,
          0,
          tokenPath,
          adapterAddresses,
          ownerAddress,
        ),
      ).to.changeEtherBalance(owner, amountOut)
      // console.log("From token to GAS")
    } else if (tokenInName == "weth") {
      await expect(() =>
        router.swapFromGAS(
          amountIn,
          0,
          tokenPath,
          adapterAddresses,
          ownerAddress,
          { value: amountIn },
        ),
      ).to.changeTokenBalance(tokenOut, owner, amountOut)
      // console.log("From GAS to token")
    } else {
      await expect(() =>
        router.swap(amountIn, 0, tokenPath, adapterAddresses, ownerAddress),
      ).to.changeTokenBalance(tokenOut, owner, amountOut)
      // console.log("From token to token")
    }
  }

  before(async function () {
    await prepare(this, [
      "Router",
      "BasicQuoter",
      "ERC20Mock",
      "ERC20MockDecimals",
      "WETH9",

      "SynapseBasePoolAdapter",
      "UniswapV2Adapter",
      "UniswapV2Factory",
    ])

    owner = this.owner
    ownerAddress = this.ownerAddress

    // Let's make OWNER crazy rich
    await network.provider.send("hardhat_setBalance", [
      ownerAddress,
      "0xFFFFFFFFFFFFFFFFFFFF",
    ])

    dude = this.dude
    dudeAddress = await dude.getAddress()

    signers = this.signers
  })

  const setupTest = deployments.createFixture(
    async ({ deployments, ethers }) => {
      const { get } = deployments
      await deployments.fixture() // ensure you start from a fresh deployments

      swapFactory = await ethers.getContractFactory("Swap", {
        libraries: {
          SwapUtils: (await get("SwapUtils")).address,
          AmplificationUtils: (await get("AmplificationUtils")).address,
        },
      })

      lpTokenAddress = (await get("LPToken")).address
    },
  )

  beforeEach(async function () {
    await setupTest()

    let amount = 10000

    for (let token in decimals) {
      let tokenAmount = getBigNumber(amount, decimals[token])
      if (token == "weth") {
        await deploy(this, [[token, this.WETH9, []]])
      } else {
        await deploy(this, [
          [
            token,
            this.ERC20MockDecimals,
            [token, token, tokenAmount, decimals[token]],
          ],
        ])
      }
    }

    weth = this.weth

    await weth.deposit({ value: getBigNumber(amount) })

    await setupSynapsePool(
      this,
      swapFactory,
      this.SynapseBasePoolAdapter,
      lpTokenAddress,
      "usdPool",
      "adapterUSD",
      [this.dai, this.usdc, this.usdt],
      [18, 6, 6],
      1000,
      2 * 10 ** 6,
      1000,
    )

    await setupSynapsePool(
      this,
      swapFactory,
      this.SynapseBasePoolAdapter,
      lpTokenAddress,
      "ethPool",
      "adapterETH",
      [this.neth, this.weth],
      [18, 18],
      1000,
      2 * 10 ** 6,
      1000,
    )

    // Uniswap forks aren't exactly original in their naming, neither am I
    await deploy(this, [
      ["aaaSwapFactory", this.UniswapV2Factory, [ownerAddress]],
      ["bbbSwapFactory", this.UniswapV2Factory, [ownerAddress]],
      ["cccSwapFactory", this.UniswapV2Factory, [ownerAddress]],
    ])

    await setupUniswapAdapters(
      this,
      this.UniswapV2Adapter,
      ["aaaSwapFactory", "bbbSwapFactory", "cccSwapFactory"],
      ["adapterAAA", "adapterBBB", "adapterCCC"],
    )

    for (let factory in seededLiquidity) {
      for (let config of seededLiquidity[factory]) {
        await setupUniswapPool(
          this,
          this[factory],
          this[config.tokenA],
          config.amountA,
          decimals[config.tokenA],
          this[config.tokenB],
          config.amountB,
          decimals[config.tokenB],
        )
      }
    }

    // ignore Bridge testing for now
    await deploy(this, [
      ["router", this.Router, [this.weth.address, 4, ZERO_ADDRESS]],
    ])

    await deploy(this, [["quoter", this.BasicQuoter, [this.router.address, 4]]])

    router = this.router
    quoter = this.quoter

    await router.grantRole(ADAPTERS_STORAGE_ROLE, this.quoter.address)

    adapters = [
      this.adapterUSD,
      this.adapterETH,
      this.adapterAAA,
      this.adapterBBB,
      this.adapterCCC,
    ]

    await quoter.setAdapters(
      adapters.map(function (adapter) {
        return adapter.address
      }),
    )

    for (let token in decimals) {
      await this[token].approve(router.address, MAX_UINT256)
    }
  })

  describe("Router: 1-step Swap", function () {
    it("Direct Swap via Synapse pool", async function () {
      await checkRouterSwap(this, ["usdt", "usdc"], [synUSD], 5)
      await checkRouterSwap(this, ["usdc", "dai"], [synUSD], 10)
      await checkRouterSwap(this, ["usdc", "usdt"], [synUSD], 2)
      await checkRouterSwap(this, ["usdt", "usdc"], [synUSD], 2)
      await checkRouterSwap(this, ["dai", "usdt"], [synUSD], 7)
    })

    it("Direct Swap via Synapse pool from/to GAS", async function () {
      await checkRouterSwap(this, ["weth", "neth"], [synETH], 1)
      await checkRouterSwap(this, ["weth", "neth"], [synETH], 10)
      await checkRouterSwap(this, ["neth", "weth"], [synETH], 5)
      await checkRouterSwap(this, ["neth", "weth"], [synETH], 12)
    })

    it("Direct Swap via Uniswap pool", async function () {
      await checkRouterSwap(this, ["usdc", "gmx"], [uniAAA], 10)
      await checkRouterSwap(this, ["wbtc", "usdc"], [uniBBB], 1)
      await checkRouterSwap(this, ["dai", "usdc"], [uniCCC], 2)

      await checkRouterSwap(this, ["gmx", "usdc"], [uniAAA], 2)
      await checkRouterSwap(this, ["usdc", "wbtc"], [uniBBB], 13)
      await checkRouterSwap(this, ["usdc", "dai"], [uniCCC], 42)
    })

    it("Direct Swap via Uniswap pool from/to GAS", async function () {
      await checkRouterSwap(this, ["weth", "wbtc"], [uniAAA], 5)
      await checkRouterSwap(this, ["weth", "dai"], [uniBBB], 6)
      await checkRouterSwap(this, ["weth", "wbtc"], [uniCCC], 9)

      await checkRouterSwap(this, ["usdt", "weth"], [uniAAA], 20)
      await checkRouterSwap(this, ["dai", "weth"], [uniBBB], 12)
      await checkRouterSwap(this, ["wbtc", "weth"], [uniCCC], 6)
    })
  })

  describe("Router: 2-step Swap", function () {
    it("Synapse + Uniswap", async function () {
      await checkRouterSwap(this, ["usdt", "usdc", "gmx"], [synUSD, uniAAA], 3)
      await checkRouterSwap(this, ["dai", "usdc", "wbtc"], [synUSD, uniBBB], 10)
      await checkRouterSwap(this, ["usdc", "dai", "usdc"], [synUSD, uniCCC], 5)

      await checkRouterSwap(this, ["gmx", "usdc", "dai"], [uniAAA, synUSD], 13)
      await checkRouterSwap(this, ["wbtc", "usdc", "usdt"], [uniBBB, synUSD], 2)
      await checkRouterSwap(this, ["dai", "usdc", "usdt"], [uniCCC, synUSD], 4)
    })

    it("Synapse + Uniswap to/from GAS", async function () {
      await checkRouterSwap(this, ["weth", "neth", "ohm"], [synETH, uniAAA], 4)
      await checkRouterSwap(this, ["weth", "neth", "usdt"], [synETH, uniBBB], 5)
      await checkRouterSwap(this, ["weth", "neth", "syn"], [synETH, uniCCC], 6)

      await checkRouterSwap(this, ["ohm", "neth", "weth"], [uniAAA, synETH], 69)
      await checkRouterSwap(
        this,
        ["usdt", "neth", "weth"],
        [uniBBB, synETH],
        42,
      )
      await checkRouterSwap(this, ["syn", "neth", "weth"], [uniCCC, synETH], 13)
    })

    it("Uniswap + Uniswap", async function () {
      await checkRouterSwap(this, ["wbtc", "usdc", "gmx"], [uniBBB, uniAAA], 3)
      await checkRouterSwap(this, ["wbtc", "usdt", "neth"], [uniBBB, uniBBB], 4)
      await checkRouterSwap(this, ["dai", "usdc", "gmx"], [uniCCC, uniAAA], 61)

      await checkRouterSwap(this, ["wbtc", "weth", "usdt"], [uniAAA, uniAAA], 2)
      await checkRouterSwap(this, ["usdt", "weth", "dai"], [uniAAA, uniBBB], 19)
      await checkRouterSwap(this, ["wbtc", "weth", "wbtc"], [uniCCC, uniAAA], 1)
    })

    it("Uniswap + Uniswap to/from GAS", async function () {
      await checkRouterSwap(this, ["weth", "wbtc", "usdc"], [uniAAA, uniBBB], 9)
      await checkRouterSwap(this, ["weth", "dai", "usdc"], [uniBBB, uniCCC], 4)
      await checkRouterSwap(
        this,
        ["weth", "wbtc", "usdt"],
        [uniCCC, uniBBB],
        61,
      )

      await checkRouterSwap(this, ["usdc", "wbtc", "weth"], [uniBBB, uniAAA], 2)
      await checkRouterSwap(this, ["usdc", "dai", "weth"], [uniCCC, uniBBB], 19)
      await checkRouterSwap(this, ["usdt", "wbtc", "weth"], [uniBBB, uniCCC], 1)
    })
  })
})
