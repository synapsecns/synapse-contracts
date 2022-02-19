//@ts-nocheck
import { BigNumber, Signer } from "ethers"
import { MAX_UINT256, getUserTokenBalance } from "../../../amm/testUtils"
import { solidity } from "ethereum-waffle"
import { deployments } from "hardhat"

import { TestAdapterSwap } from "../build/typechain/TestAdapterSwap"
import { IERC20 } from "../../../../build/typechain/IERC20"
import { CurveLendingPoolAdapter } from "../../../../build/typechain/CurveLendingPoolAdapter"
import chai from "chai"
import { getBigNumber } from "../../../bridge/utilities"
import { setBalance } from "../../utils/helpers"

import config from "../../../config.json"

chai.use(solidity)
const { expect } = chai

describe("Curve Aave Pool (AVAX) Adapter", async () => {
  let signers: Array<Signer>

  let owner: Signer
  let ownerAddress: string
  let dude: Signer
  let dudeAddress: string

  let curveLendingPoolAdapter: CurveLendingPoolAdapter

  let testAdapterSwap: TestAdapterSwap

  // Test Values
  const TOKENS: IERC20[] = []

  const CHAIN = 43114
  const DEX = "curve"

  const TOKENS_DECIMALS = []
  const tokenSymbols = ["DAIe", "USDCe", "USDTe"]

  const DIRECT_SWAP_SUPPORTED = false

  const range = (n) => Array.from({ length: n }, (value, key) => key)
  const ALL_TOKENS = range(tokenSymbols.length)

  const AMOUNTS = [8, 1001, 96420, 1337000]
  const AMOUNTS_BIG = [4500600, 10200300]
  const CHECK_UNDERQUOTING = true

  async function testAdapter(
    adapter: Adapter,
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
      await deployments.fixture() // ensure you start from a fresh deployments

      TOKENS.length = 0
      signers = await ethers.getSigners()
      owner = signers[0]
      ownerAddress = await owner.getAddress()
      dude = signers[1]
      dudeAddress = await dude.getAddress()

      const testFactory = await ethers.getContractFactory("TestAdapterSwap")

      // we expect the quory to underQuote by 1 at maximum
      testAdapterSwap = (await testFactory.deploy(1)) as TestAdapterSwap

      for (let symbol of tokenSymbols) {
        let tokenAddress = config[CHAIN].assets[symbol]
        let storageSlot = config[CHAIN].slot[symbol]
        let token = (await ethers.getContractAt(
          "contracts/amm/SwapCalculator.sol:IERC20Decimals",
          tokenAddress,
        )) as IERC20Decimals
        TOKENS.push(token)
        let decimals = await token.decimals()
        TOKENS_DECIMALS.push(decimals)
        let amount = getBigNumber(1e12, decimals)
        await setBalance(ownerAddress, tokenAddress, amount, storageSlot)
        expect(await getUserTokenBalance(ownerAddress, token)).to.eq(amount)
      }

      const curveAdapterFactory = await ethers.getContractFactory(
        "CurveLendingPoolAdapter",
      )

      curveLendingPoolAdapter = (await curveAdapterFactory.deploy(
        "CurveBaseAdapter",
        config[CHAIN][DEX].aave,
        160000,
        DIRECT_SWAP_SUPPORTED
      )) as CurveLendingPoolAdapter

      for (let token of TOKENS) {
        await token.approve(testAdapterSwap.address, MAX_UINT256)
      }
    },
  )

  before(async () => {
    console.log("Direct swaps = %s", DIRECT_SWAP_SUPPORTED)
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: process.env.AVAX_API,
            blockNumber: 10000000, // 2022-01-24
          },
        },
      ],
    })
  })

  beforeEach(async () => {
    await setupTest()
  })

  describe("Sanity checks", () => {
    it("Curve Adapter is properly set up", async () => {
      expect(await curveLendingPoolAdapter.pool()).to.eq(config[CHAIN][DEX].aave)

      for (let i in TOKENS) {
        let token = TOKENS[i].address
        expect(await curveLendingPoolAdapter.isPoolToken(token))
        expect(await curveLendingPoolAdapter.tokenIndex(token)).to.eq(+i)
      }
    })

    it("Swap fails if transfer amount is too little", async () => {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let depositAddress = await curveLendingPoolAdapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.sub(1))
      await expect(
        curveLendingPoolAdapter.swap(
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
      let depositAddress = await curveLendingPoolAdapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.add(extra))
      await curveLendingPoolAdapter.swap(
        amount,
        TOKENS[0].address,
        TOKENS[1].address,
        ownerAddress,
      )

      await expect(
        curveLendingPoolAdapter
          .connect(dude)
          .recoverERC20(TOKENS[0].address, extra),
      ).to.be.revertedWith("Ownable: caller is not the owner")

      await expect(() =>
        curveLendingPoolAdapter.recoverERC20(TOKENS[0].address, extra),
      ).to.changeTokenBalance(TOKENS[0], owner, extra)
    })

    it("Anyone can take advantage of overprovided swap tokens", async () => {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let extra = getBigNumber(42, TOKENS_DECIMALS[0] - 1)
      let depositAddress = await curveLendingPoolAdapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.add(extra))
      await curveLendingPoolAdapter.swap(
        amount,
        TOKENS[0].address,
        TOKENS[1].address,
        ownerAddress,
      )

      let swapQuote = await curveLendingPoolAdapter.query(
        extra,
        TOKENS[0].address,
        TOKENS[1].address,
      )

      // .add(1) to reflect underquoting by 1
      await expect(() =>
        curveLendingPoolAdapter
          .connect(dude)
          .swap(extra, TOKENS[0].address, TOKENS[1].address, dudeAddress),
      ).to.changeTokenBalance(TOKENS[1], dude, swapQuote.add(1))
    })

    it("Only Owner can rescue GAS from Adapter", async () => {
      let amount = 42690
      await expect(() =>
        owner.sendTransaction({
          to: curveLendingPoolAdapter.address,
          value: amount,
        }),
      ).to.changeEtherBalance(curveLendingPoolAdapter, amount)

      await expect(
        curveLendingPoolAdapter.connect(dude).recoverGAS(amount),
      ).to.be.revertedWith("Ownable: caller is not the owner")

      await expect(() =>
        curveLendingPoolAdapter.recoverGAS(amount),
      ).to.changeEtherBalances(
        [curveLendingPoolAdapter, owner],
        [-amount, amount],
      )
    })
  })

  describe("Adapter Swaps", () => {
    it("Swaps between tokens [120 small-medium swaps]", async () => {
      await testAdapter(curveLendingPoolAdapter, ALL_TOKENS, ALL_TOKENS, 5)
    })

    it("Swaps between tokens [120 big-ass swaps]", async () => {
      await testAdapter(
        curveLendingPoolAdapter,
        ALL_TOKENS,
        ALL_TOKENS,
        10,
        AMOUNTS_BIG,
      )
    })
  })
})
