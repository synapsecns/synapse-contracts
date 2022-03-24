//@ts-nocheck
import { Signer } from "ethers"
import { MAX_UINT256, getUserTokenBalance } from "../../../utils"
import { solidity } from "ethereum-waffle"
import { deployments } from "hardhat"

import { TestSolidlyAdapter } from "../build/typechain/TestSolidlyAdapter"
import { GenericERC20 } from "../../../../build/typechain/GenericERC20"
import { IERC20Decimals } from "../../../../build/typechain/IERC20Decimals"

import chai from "chai"
import { getBigNumber } from "../../../bridge/utilities"
import { forkChain, setBalance } from "../../utils/helpers"

import config from "../../../config.json"

chai.use(solidity)
const { expect } = chai

describe("Solidly Adapter", async function () {
  let signers: Array<Signer>

  let owner: Signer
  let ownerAddress: string
  let dude: Signer
  let dudeAddress: string

  let solidlyAdapter: SolidlyAdapter

  let testAdapterSwap: TestSolidlyAdapter

  let baseTokens: Array<number>
  let allTokens: Array<number>

  const CHAIN = 250
  const DEX = "solidly"

  const TOKENS: GenericERC20[] = []
  const TOKENS_DECIMALS = []

  const AMOUNTS = [1, 6, 13, 37]
  const CHECK_UNDERQUOTING = true

  const range = (n) => Array.from({ length: n }, (value, key) => key)

  const STABLE = false
  const tokenSymbols = ["WFTM", "ETH", "BTC", "USDC", "fUSDT"]

  // const STABLE = true
  // const tokenSymbols = ["MIM", "USDC", "DAI", "WFTM", "fUSDT"]

  const baseTokens = [0]
  const allTokens = range(tokenSymbols.length)

  async function testAdapter(
    adapter: SolidlyAdapter,
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
          for (let j of tokensTo) {
            if (i == j) {
              continue
            }
            let tokenTo = tokens[j]

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
    console.log("Swaps: %s", swapsAmount)
  }

  async function setupTest() {
    TOKENS.length = 0
    signers = await ethers.getSigners()
    owner = signers[0]
    ownerAddress = await owner.getAddress()
    dude = signers[1]
    dudeAddress = await dude.getAddress()

    const solidlyAdapterFactory = await ethers.getContractFactory(
      "SolidlyAdapter",
    )

    solidlyAdapter = (await solidlyAdapterFactory.deploy(
      "SolidlyAdapter",
      160000,
      config[CHAIN][DEX].factory,
      config[CHAIN][DEX].hash,
      STABLE,
    )) as SolidlyAdapter

    const testFactory = await ethers.getContractFactory("TestSolidlyAdapter")

    testAdapterSwap = (await testFactory.deploy(
      config[CHAIN][DEX].router,
      STABLE,
    )) as TestSolidlyAdapter

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
  }

  before(async function () {
    // 2022-03-21
    await forkChain(process.env.FTM_API, 34000000)
  })

  beforeEach(async function () {
    await setupTest()
  })

  describe("Sanity checks", function () {
    it("Solidly Adapter is properly set up", async function () {
      expect(await solidlyAdapter.solidlyFactory()).to.eq(
        config[CHAIN][DEX].factory,
      )
      expect(await solidlyAdapter.stable()).to.eq(STABLE)
    })

    it("Swap fails when there is no direct path between tokens", async function () {
      // BTC -> fUSDT
      let tokenFrom = 2
      let tokenTo = 4
      let amount = getBigNumber(10, TOKENS_DECIMALS[tokenFrom])

      expect(
        await solidlyAdapter.query(
          amount,
          TOKENS[tokenFrom].address,
          TOKENS[tokenTo].address,
        ),
      ).to.eq(0)

      await expect(
        solidlyAdapter.swap(
          amount,
          TOKENS[tokenFrom].address,
          TOKENS[tokenTo].address,
          ownerAddress,
        ),
      ).to.be.revertedWith("Adapter: Insufficient output amount")
    })

    it("Swap fails if transfer amount is too little", async function () {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let depositAddress = await solidlyAdapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      const BASE = 1000000
      TOKENS[0].transfer(depositAddress, amount.mul(BASE - 1).div(BASE))
      await expect(
        solidlyAdapter.swap(
          amount,
          TOKENS[0].address,
          TOKENS[1].address,
          ownerAddress,
        ),
      ).to.be.reverted
    })

    it("Noone can rescue overprovided swap tokens", async function () {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let extra = getBigNumber(42, TOKENS_DECIMALS[0] - 1)
      let depositAddress = await solidlyAdapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.add(extra))
      await solidlyAdapter.swap(
        amount,
        TOKENS[0].address,
        TOKENS[1].address,
        ownerAddress,
      )

      await expect(
        solidlyAdapter.connect(dude).recoverERC20(TOKENS[0].address),
      ).to.be.revertedWith("Ownable: caller is not the owner")

      // tokens are in the UniSwap pair, not the Adapter
      await expect(solidlyAdapter.recoverERC20(TOKENS[0].address)).to.be
        .reverted
    })

    it("Noone can take advantage of overprovided swap tokens", async function () {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let extra = getBigNumber(42, TOKENS_DECIMALS[0] - 1)
      let depositAddress = await solidlyAdapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.add(extra))
      await solidlyAdapter.swap(
        amount,
        TOKENS[0].address,
        TOKENS[1].address,
        ownerAddress,
      )

      // UniSwap reserves are updated at the end of swap
      // https://github.com/Uniswap/v2-core/blob/4dd59067c76dea4a0e8e4bfdda41877a6b16dedc/contracts/UniswapV2Pair.sol#L185
      await expect(
        solidlyAdapter
          .connect(dude)
          .swap(extra, TOKENS[0].address, TOKENS[1].address, dudeAddress),
      ).to.be.reverted
    })

    it("Only Owner can rescue tokens sent to Adapter", async function () {
      let extra = getBigNumber(10, TOKENS_DECIMALS[0])
      await TOKENS[0].transfer(solidlyAdapter.address, extra)

      await expect(
        solidlyAdapter.connect(dude).recoverERC20(TOKENS[0].address),
      ).to.be.revertedWith("Ownable: caller is not the owner")

      await expect(() =>
        solidlyAdapter.recoverERC20(TOKENS[0].address),
      ).to.changeTokenBalance(TOKENS[0], owner, extra)
    })

    it("Only Owner can rescue GAS from Adapter", async function () {
      let amount = 42690
      await expect(() =>
        owner.sendTransaction({ to: solidlyAdapter.address, value: amount }),
      ).to.changeEtherBalance(solidlyAdapter, amount)

      await expect(
        solidlyAdapter.connect(dude).recoverGAS(),
      ).to.be.revertedWith("Ownable: caller is not the owner")

      await expect(() => solidlyAdapter.recoverGAS()).to.changeEtherBalances(
        [solidlyAdapter, owner],
        [-amount, amount],
      )
    })
  })

  describe("Adapter Swaps from Base tokens", function () {
    it("Swaps and Queries from Base (32 swaps)", async function () {
      await testAdapter(solidlyAdapter, baseTokens, allTokens, 2)
    })
  })

  describe("Adapter Swaps to Base tokens", function () {
    it("Swaps and Queries to Base (32 swaps)", async function () {
      await testAdapter(solidlyAdapter, allTokens, baseTokens, 2)
    })
  })
})
