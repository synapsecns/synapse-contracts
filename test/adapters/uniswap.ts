//@ts-nocheck
import { Signer } from "ethers"
import { MAX_UINT256, getUserTokenBalance } from "../amm/testUtils"
import { solidity } from "ethereum-waffle"
import { deployments } from "hardhat"

import { TestUniswapAdapter } from "../build/typechain/TestUniswapAdapter"
import { GenericERC20 } from "../../build/typechain/GenericERC20"
import { IERC20Decimals } from "../../build/typechain/IERC20Decimals"
import { IWETH9 } from "../../build/typechain/IWETH9"

import chai from "chai"
import { getBigNumber } from "../bridge/utilities"
import { setBalance } from "./utils/helpers"

import config from "../config.json"

chai.use(solidity)
const { expect } = chai

describe("Uniswap Adapter", async () => {
  let signers: Array<Signer>

  let owner: Signer
  let ownerAddress: string
  let dude: Signer
  let dudeAddress: string

  let uniswapAdapter: UniswapAdapter

  let testAdapterSwap: TestUniswapAdapter

  let baseTokens: Array<number>
  let allTokens: Array<number>

  const TOKENS: GenericERC20[] = []
  const TOKENS_DECIMALS = []

  const AMOUNTS = [1, 13, 96]
  const CHECK_UNDERQUOTING = true

  async function testAdapter(
    adapter: UniswapAdapter,
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
        "UniswapAdapter",
      )

      uniswapAdapter = (await uniswapAdapterFactory.deploy(
        "UniswapAdapter",
        config[43114].traderjoe.factory,
        160000,
      )) as UniswapAdapter

      const testFactory = await ethers.getContractFactory("TestUniswapAdapter")

      testAdapterSwap = (await testFactory.deploy(
        config[43114].traderjoe.router,
      )) as TestUniswapAdapter

      let tokens = [
        config[43114].assets.WAVAX,
        config[43114].assets.USDCe,
        config[43114].assets.WETHe,
        config[43114].assets.WBTCe,
        config[43114].assets.LINKe,
        config[43114].assets.JOE,
      ]

      baseTokens = [0, 1]
      allTokens = [0, 1, 2, 3, 4, 5]

      for (let tokenAddress of tokens) {
        let token = (await ethers.getContractAt(
          "contracts/router/helper/SwapAddCalculator.sol:IERC20Decimals",
          tokenAddress,
        )) as IERC20Decimals
        TOKENS.push(token)
        let decimals = await token.decimals()
        TOKENS_DECIMALS.push(decimals)
        let amount = getBigNumber(5000, decimals)

        if (tokenAddress == config[43114].assets.WAVAX) {
          token = (await ethers.getContractAt(
            "@synapseprotocol/sol-lib/contracts/universal/interfaces/IWETH9.sol:IWETH9",
            tokenAddress,
          )) as IWETH9
          token.deposit({ value: amount })
        } else {
          await setBalance(ownerAddress, tokenAddress, amount)
        }
        expect(await getUserTokenBalance(owner, token)).to.be.eq(amount)

        token.approve(testAdapterSwap.address, MAX_UINT256)
      }
    },
  )

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

  describe("Sanity checks", () => {
    it("Uniswap Adapter is properly set up", async () => {
      expect(await uniswapAdapter.uniswapV2Factory()).to.eq(
        config[43114].traderjoe.factory,
      )
    })

    it("Swap fails when there is no direct path between tokens", async () => {
      // WETHe -> LINKe
      let amount = getBigNumber(10, TOKENS_DECIMALS[2])

      expect(
        await uniswapAdapter.query(
          amount,
          TOKENS[2].address,
          TOKENS[4].address,
        ),
      ).to.eq(0)

      await expect(
        uniswapAdapter.swap(
          amount,
          TOKENS[2].address,
          TOKENS[4].address,
          ownerAddress,
        ),
      ).to.be.revertedWith("Swap pool does not exist")
    })

    it("Swap fails if transfer amount is too little", async () => {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let depositAddress = await uniswapAdapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      const BASE = 1000000
      TOKENS[0].transfer(depositAddress, amount.mul(BASE - 1).div(BASE))
      await expect(
        uniswapAdapter.swap(
          amount,
          TOKENS[0].address,
          TOKENS[1].address,
          ownerAddress,
        ),
      ).to.be.reverted
    })

    it("Noone can rescue overprovided swap tokens", async () => {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let extra = getBigNumber(42, TOKENS_DECIMALS[0] - 1)
      let depositAddress = await uniswapAdapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.add(extra))
      await uniswapAdapter.swap(
        amount,
        TOKENS[0].address,
        TOKENS[1].address,
        ownerAddress,
      )

      await expect(
        uniswapAdapter.connect(dude).recoverERC20(TOKENS[0].address, extra),
      ).to.be.revertedWith("Ownable: caller is not the owner")

      // tokens are in the UniSwap pair, not the Adapter
      await expect(uniswapAdapter.recoverERC20(TOKENS[0].address, extra)).to.be
        .reverted
    })

    it("Noone can take advantage of overprovided swap tokens", async () => {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let extra = getBigNumber(42, TOKENS_DECIMALS[0] - 1)
      let depositAddress = await uniswapAdapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.add(extra))
      await uniswapAdapter.swap(
        amount,
        TOKENS[0].address,
        TOKENS[1].address,
        ownerAddress,
      )

      // UniSwap reserves are updated at the end of swap
      // https://github.com/Uniswap/v2-core/blob/4dd59067c76dea4a0e8e4bfdda41877a6b16dedc/contracts/UniswapV2Pair.sol#L185
      await expect(
        uniswapAdapter
          .connect(dude)
          .swap(extra, TOKENS[0].address, TOKENS[1].address, dudeAddress),
      ).to.be.reverted
    })

    it("Only Owner can rescue tokens sent to Adapter", async () => {
      let extra = getBigNumber(10, TOKENS_DECIMALS[0])
      await TOKENS[0].transfer(uniswapAdapter.address, extra)

      await expect(
        uniswapAdapter.connect(dude).recoverERC20(TOKENS[0].address, extra),
      ).to.be.revertedWith("Ownable: caller is not the owner")

      await expect(() =>
        uniswapAdapter.recoverERC20(TOKENS[0].address, extra),
      ).to.changeTokenBalance(TOKENS[0], owner, extra)
    })

    it("Only Owner can rescue GAS from Adapter", async () => {
      let amount = 42690
      await expect(() =>
        owner.sendTransaction({ to: uniswapAdapter.address, value: amount }),
      ).to.changeEtherBalance(uniswapAdapter, amount)

      await expect(
        uniswapAdapter.connect(dude).recoverGAS(amount),
      ).to.be.revertedWith("Ownable: caller is not the owner")

      await expect(() =>
        uniswapAdapter.recoverGAS(amount),
      ).to.changeEtherBalances([uniswapAdapter, owner], [-amount, amount])
    })
  })

  describe("Adapter Swaps from Base tokens", () => {
    it("Swaps and Queries from Base (150 swaps)", async () => {
      await testAdapter(uniswapAdapter, baseTokens, allTokens, 5)
    })
  })

  describe("Adapter Swaps to Base tokens", () => {
    it("Swaps and Queries to Base (150 swaps)", async () => {
      await testAdapter(uniswapAdapter, allTokens, baseTokens, 5)
    })
  })
})
