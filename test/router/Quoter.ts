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
  areDiffResults,
} from "./utils"
import { Router } from "../../build/typechain/Router"

import chai from "chai"
import { ContractFactory, Signer } from "ethers"
import { MAX_UINT256, ZERO_ADDRESS } from "../utils"
import { Adapter, Quoter, WETH9 } from "../../build/typechain"
import { Context } from "mocha"

import {
  decimals,
  seededLiquidity,
  synUSD,
  synETH,
  uniAAA,
  uniBBB,
  uniCCC,
  adapterNames,
} from "./utils/data"

chai.use(solidity)

describe("Quoter", function () {
  let router: Router
  let quoter: Quoter

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

  function checkArrays(a: Array<string>, b: Array<string>) {
    expect(a.length).to.eq(b.length)
    for (let index in a) {
      expect(a[index]).to.eq(b[index])
    }
  }

  function findTokenName(thisObject: Context, address: string): string {
    for (let tokenName in decimals) {
      if (thisObject[tokenName].address === address) {
        return tokenName
      }
    }
    return "???"
  }

  function findAdapterName(address: string) {
    for (let index in adapters) {
      if (adapters[index].address === address) {
        return adapterNames[index]
      }
    }
    return "???"
  }

  async function checkQuoter(
    thisObject: Context,
    tokenNames: Array<string>,
    adapterIndexes: Array<number>,
    amount: number = 1,
    maxSwaps: number = 3,
    gasPrice: number = 0,
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

    let bestPath = await quoter.findBestPathWithGas(
      amountIn,
      thisObject[tokenInName].address,
      thisObject[tokenOutName].address,
      maxSwaps,
      gasPrice,
    )

    if (
      areDiffResults(
        tokenPath,
        adapterAddresses,
        bestPath.path,
        bestPath.adapters,
      )
    ) {
      let dec = 10 ** decimals[tokenOutName]
      console.log(
        "Expected amountOut: ",
        (amountOut.toNumber() / dec).toFixed(4),
      )
      console.log(
        tokenPath.map(function (a) {
          return findTokenName(thisObject, a)
        }),
      )
      console.log(
        adapterAddresses.map(function (a) {
          return findAdapterName(a)
        }),
      )
      amountOut = bestPath.amounts[bestPath.amounts.length - 1]
      console.log("Found amountOut: ", (amountOut.toNumber() / dec).toFixed(4))
      console.log(
        bestPath.path.map(function (a) {
          return findTokenName(thisObject, a)
        }),
      )
      console.log(
        bestPath.adapters.map(function (a) {
          return findAdapterName(a)
        }),
      )
    }

    checkArrays(bestPath.path, tokenPath)
    checkArrays(bestPath.adapters, adapterAddresses)
  }

  before(async function () {
    await prepare(this, [
      "Router",
      "Quoter",
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

    let amount = 1000000

    let tokenAddresses: Array<string> = []

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
      tokenAddresses.push(this[token].address)
    }

    weth = this.weth

    await weth.deposit({ value: getBigNumber(9000) })

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
      100000,
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
    await deploy(this, [["router", this.Router, [this.weth.address]]])

    await deploy(this, [["quoter", this.Quoter, [this.router.address, 4]]])

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

    await quoter.setTokens(tokenAddresses)

    for (let token in decimals) {
      await this[token].approve(router.address, MAX_UINT256)
    }
  })

  describe("Finding best path ignoring gas", function () {
    it("1-step swap", async function () {
      // 1 WBTC -> WETH
      await checkQuoter(this, ["wbtc", "weth"], [uniAAA], 1)

      // 40 DAI -> USDC
      await checkQuoter(this, ["dai", "usdc"], [uniCCC], 40)

      // 100 DAI -> USDC
      await checkQuoter(this, ["dai", "usdc"], [synUSD], 100)

      // 5 WBTC -> USDT
      await checkQuoter(this, ["wbtc", "usdt"], [uniBBB], 5)
    })

    it("2-step swap", async function () {
      // 1 WBTC -> USDT
      await checkQuoter(this, ["wbtc", "usdc", "usdt"], [uniBBB, synUSD], 1)

      // 100 DAI -> WBTC
      await checkQuoter(this, ["dai", "usdt", "wbtc"], [synUSD, uniBBB], 100)
    })

    it("3-step swap", async function () {
      // 10 DAI -> USDC
      await checkQuoter(
        this,
        ["dai", "weth", "wbtc", "usdc"],
        [uniBBB, uniCCC, uniBBB],
        10,
      )

      // 10 DAI -> WBTC
      await checkQuoter(
        this,
        ["dai", "usdc", "usdt", "wbtc"],
        [uniCCC, synUSD, uniBBB],
        10,
      )
    })
  })
})
