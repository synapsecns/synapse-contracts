//@ts-nocheck
import { BigNumber, Signer } from "ethers"
import { MAX_UINT256, getUserTokenBalance } from "../amm/testUtils"
import { solidity } from "ethereum-waffle"
import { deployments } from "hardhat"

import { TestAdapterSwap } from "../build/typechain/TestAdapterSwap"
import { ILendingPool } from "../build/typechain/ILendingPool"
import { GenericERC20 } from "../../build/typechain/GenericERC20"
import { LPToken } from "../../build/typechain/LPToken"
import { Swap } from "../../build/typechain/Swap"
import { SynapseAavePoolAdapter } from "../../build/typechain/SynapseAavePoolAdapter"
import chai from "chai"
import { getBigNumber } from "../bridge/utilities"
import { setBalance } from "./utils/helpers"

import config from "../config.json"

chai.use(solidity)
const { expect } = chai

describe("Aave Pool Adapter", async () => {
  let signers: Array<Signer>
  let swap: Swap
  let swapETH: Swap

  let swapToken: LPToken
  let owner: Signer
  let ownerAddress: string
  let dude: Signer
  let dudeAddress: string

  let aavePoolAdapter: SynapseAavePoolAdapter
  let aaveEthPoolAdapter: SynapseAavePoolAdapter
  let aaveLendingPool: ILendingPool

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
  const TOKENS_ETH: GenericERC20[] = []
  const TOKENS_DECIMALS = [18, 18, 6, 6]
  const DECIMALS_ETH = [18, 18]
  const AMOUNTS = [1, 7, 13, 42]
  const AMOUNTS_BIG = [137, 304, 555]
  const CHECK_UNDERQUOTING = true

  async function testAdapter(
    adapter: SynapseBasePoolAdapter,
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

      const testFactory = await ethers.getContractFactory("TestAdapterSwap")

      testAdapterSwap = (await testFactory.deploy()) as TestAdapterSwap

      // Deploy dummy tokens
      const erc20Factory = await ethers.getContractFactory("GenericERC20")

      let NUSD = (await erc20Factory.deploy(
        "nUSD",
        "nUSD",
        "18",
      )) as GenericERC20
      await NUSD.mint(ownerAddress, getBigNumber(100000, TOKENS_DECIMALS[0]))

      let NETH = (await erc20Factory.deploy(
        "nETH",
        "nETH",
        "18",
      )) as GenericERC20
      await NETH.mint(ownerAddress, getBigNumber(100000))

      let poolTokens = [
        NUSD.address,
        config[43114].assets.avDAI,
        config[43114].assets.avUSDC,
        config[43114].assets.avUSDT,
      ]

      let underlyingTokens = [
        NUSD.address,
        config[43114].assets.DAIe,
        config[43114].assets.USDCe,
        config[43114].assets.USDTe,
      ]

      let ethPoolTokens = [NETH.address, config[43114].assets.avWETH]

      let ethUnderlyingTokens = [NETH.address, config[43114].assets.WETHe]

      for (var i = 1; i < underlyingTokens.length; i++) {
        await setBalance(
          ownerAddress,
          underlyingTokens[i],
          getBigNumber(100000, TOKENS_DECIMALS[i]),
        )
      }

      await setBalance(
        ownerAddress,
        ethUnderlyingTokens[1],
        getBigNumber(100000),
      )

      // Deploy Swap with SwapUtils library
      const swapFactory = await ethers.getContractFactory("Swap", {
        libraries: {
          SwapUtils: (await get("SwapUtils")).address,
          AmplificationUtils: (await get("AmplificationUtils")).address,
        },
      })
      swap = (await swapFactory.deploy()) as Swap

      await swap.initialize(
        poolTokens,
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

      swapETH = (await swapFactory.deploy()) as Swap

      await swapETH.initialize(
        ethPoolTokens,
        [18, 18],
        "nETH LP token",
        "nETH-LP",
        INITIAL_A_VALUE,
        SWAP_FEE,
        0,
        (
          await get("LPToken")
        ).address,
      )

      TOKENS.push(
        NUSD,
        await ethers.getContractAt(
          "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol:IERC20",
          config[43114].assets.DAIe,
        ),
        await ethers.getContractAt(
          "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol:IERC20",
          config[43114].assets.USDCe,
        ),
        await ethers.getContractAt(
          "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol:IERC20",
          config[43114].assets.USDTe,
        ),
      )

      TOKENS_ETH.push(
        NETH,
        await ethers.getContractAt(
          "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol:IERC20",
          config[43114].assets.WETHe,
        ),
      )

      const aavePoolAdapterFactory = await ethers.getContractFactory(
        "SynapseAavePoolAdapter",
      )

      aavePoolAdapter = (await aavePoolAdapterFactory.deploy(
        "aavePoolAdapter",
        swap.address,
        160000,
        config[43114].aave.lendingpool,
        underlyingTokens,
      )) as SynapseAavePoolAdapter

      aaveEthPoolAdapter = (await aavePoolAdapterFactory.deploy(
        "aaveEthPoolAdapter",
        swapETH.address,
        160000,
        config[43114].aave.lendingpool,
        ethUnderlyingTokens,
      )) as SynapseAavePoolAdapter

      aaveLendingPool = (await ethers.getContractAt(
        "contracts/router/interfaces/ILendingPool.sol:ILendingPool",
        config[43114].aave.lendingpool,
      )) as ILendingPool

      for (var i = 1; i < underlyingTokens.length; i++) {
        let token = TOKENS[i]
        let amount = getBigNumber(1000, TOKENS_DECIMALS[i])
        await token.approve(config[43114].aave.lendingpool, amount)
        await aaveLendingPool.deposit(
          underlyingTokens[i],
          amount,
          ownerAddress,
          0,
        )
      }

      let amountETH = getBigNumber(1000)
      await TOKENS_ETH[1].approve(config[43114].aave.lendingpool, amountETH)
      await aaveLendingPool.deposit(
        ethUnderlyingTokens[1],
        amountETH,
        ownerAddress,
        0,
      )

      let amounts = [
        getBigNumber(1000, TOKENS_DECIMALS[0]),
        getBigNumber(1000, TOKENS_DECIMALS[1]),
        getBigNumber(1000, TOKENS_DECIMALS[2]),
        getBigNumber(1000, TOKENS_DECIMALS[3]),
      ]

      for (let i in poolTokens) {
        let token = await ethers.getContractAt(
          "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol:IERC20",
          poolTokens[i],
        )
        await token.approve(swap.address, amounts[i])
      }

      for (let tokenName of ethPoolTokens) {
        let token = await ethers.getContractAt(
          "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol:IERC20",
          tokenName,
        )
        await token.approve(swapETH.address, amountETH)
      }

      for (let token of TOKENS) {
        await token.approve(testAdapterSwap.address, MAX_UINT256)
      }

      for (let token of TOKENS_ETH) {
        await token.approve(testAdapterSwap.address, MAX_UINT256)
      }

      // Populate the pool with initial liquidity
      await swap.addLiquidity(amounts, 0, MAX_UINT256)

      for (let i in amounts) {
        expect(await swap.getTokenBalance(i)).to.be.eq(amounts[i])
      }

      await swapETH.addLiquidity([amountETH, amountETH], 0, MAX_UINT256)
      for (let i in TOKENS_ETH) {
        expect(await swapETH.getTokenBalance(i)).to.be.eq(amountETH)
      }
    },
  )

  async function checkPool(adapter, pool, tokens) {
    expect(await adapter.pool()).to.be.eq(pool.address)
    expect(await adapter.numTokens()).to.be.eq(tokens.length)
    expect(await adapter.swapFee()).to.be.eq(SWAP_FEE)

    for (let i in tokens) {
      let token = tokens[i].address
      let isPool = await adapter.isPoolToken(token)
      if (isPool) {
        expect(+i).to.eq(0)
        expect(await adapter.tokenIndex(token)).to.eq(+i)
      } else {
        expect(+i).to.gt(0)
        expect(await adapter.isUnderlying(token))
        let aaveToken = await adapter.aaveToken(token)
        expect(await adapter.isPoolToken(aaveToken))
        expect(await adapter.tokenIndex(aaveToken)).to.eq(+i)
      }
    }
  }

  before(async () => {
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: process.env.AVAX_API,
            blockNumber: 10000000,
          },
        },
      ],
    })
  })

  beforeEach(async () => {
    await setupTest()
  })

  describe("Setup", () => {
    it("AavePool Adapter is properly set up", async () => {
      await checkPool(aavePoolAdapter, swap, TOKENS)
      await checkPool(aaveEthPoolAdapter, swapETH, TOKENS_ETH)
    })
  })

  describe("Adapter Swaps: 2 token pool", () => {
    it("Swap stress test [240 small-medium sized swaps]", async () => {
      await testAdapter(
        aaveEthPoolAdapter,
        [0, 1],
        [0, 1],
        30,
        AMOUNTS,
        TOKENS_ETH,
        DECIMALS_ETH,
      )
    })

    it("Swap stress test [180 big sized swaps]", async () => {
      await testAdapter(
        aaveEthPoolAdapter,
        [0, 1],
        [0, 1],
        30,
        AMOUNTS_BIG,
        TOKENS_ETH,
        DECIMALS_ETH,
      )
    })
  })

  describe("Adapter Swaps: 4 token pool", () => {
    it("Swaps between underlying tokens [48 small-medium sized swaps]", async () => {
      await testAdapter(aavePoolAdapter, [1, 2, 3], [1, 2, 3], 2)
    })

    it("Swaps from nUSD to underlying Token [48 small-medium sized swaps]", async () => {
      await testAdapter(aavePoolAdapter, [0], [1, 2, 3], 4)
    })

    it("Swaps from underlying Tokens to nUSD [48 small-medium sized swaps]", async () => {
      await testAdapter(aavePoolAdapter, [1, 2, 3], [0], 4)
    })

    it("Swap stress test [240 small-medium sized swaps]", async () => {
      await testAdapter(aavePoolAdapter, [0, 1, 2, 3], [0, 1, 2, 3], 5)
    })

    it("Swap stress test [180 big sized swaps]", async () => {
      await testAdapter(
        aavePoolAdapter,
        [0, 1, 2, 3],
        [0, 1, 2, 3],
        5,
        AMOUNTS_BIG,
      )
    })
  })

  describe("Wrong amount transferred", () => {
    it("Swap fails if transfer amount is too little", async () => {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let depositAddress = await aavePoolAdapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.sub(1))
      await expect(
        aavePoolAdapter.swap(
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
      let depositAddress = await aavePoolAdapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.add(extra))
      await aavePoolAdapter.swap(
        amount,
        TOKENS[0].address,
        TOKENS[1].address,
        ownerAddress,
      )

      await expect(
        aavePoolAdapter.connect(dude).recoverERC20(TOKENS[0].address, extra),
      ).to.be.revertedWith("Ownable: caller is not the owner")

      await expect(() =>
        aavePoolAdapter.recoverERC20(TOKENS[0].address, extra),
      ).to.changeTokenBalance(TOKENS[0], owner, extra)
    })

    it("Anyone can take advantage of overprovided swap tokens", async () => {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let extra = getBigNumber(42, TOKENS_DECIMALS[0] - 1)
      let depositAddress = await aavePoolAdapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.add(extra))
      await aavePoolAdapter.swap(
        amount,
        TOKENS[0].address,
        TOKENS[1].address,
        ownerAddress,
      )

      let swapQuote = await aavePoolAdapter.query(
        extra,
        TOKENS[0].address,
        TOKENS[1].address,
      )

      await expect(() =>
        aavePoolAdapter
          .connect(dude)
          .swap(extra, TOKENS[0].address, TOKENS[1].address, dudeAddress),
      ).to.changeTokenBalance(TOKENS[1], dude, swapQuote)
    })

    it("Only Owner can rescue GAS from Adapter", async () => {
      let amount = 42690
      await expect(() =>
        owner.sendTransaction({ to: aavePoolAdapter.address, value: amount }),
      ).to.changeEtherBalance(aavePoolAdapter, amount)

      await expect(
        aavePoolAdapter.connect(dude).recoverGAS(amount),
      ).to.be.revertedWith("Ownable: caller is not the owner")

      await expect(() =>
        aavePoolAdapter.recoverGAS(amount),
      ).to.changeEtherBalances([aavePoolAdapter, owner], [-amount, amount])
    })
  })
})
