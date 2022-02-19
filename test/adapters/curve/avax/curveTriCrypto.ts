//@ts-nocheck
import { BigNumber, Signer } from "ethers"
import { MAX_UINT256, getUserTokenBalance } from "../../../amm/testUtils"
import { solidity } from "ethereum-waffle"
import { deployments } from "hardhat"

import { TestAdapterSwap } from "../build/typechain/TestAdapterSwap"
import { IERC20 } from "../../../../build/typechain/IERC20"
import { CurveLendingTriCryptoAdapter } from "../../../../build/typechain/CurveLendingTriCryptoAdapter"
import chai from "chai"
import { getBigNumber } from "../../../bridge/utilities"
import { setBalance } from "../../utils/helpers"

import config from "../../../config.json"

chai.use(solidity)
const { expect } = chai

describe("Curve TriCrypto (AVAX) Adapter", async () => {
  let signers: Array<Signer>

  let owner: Signer
  let ownerAddress: string
  let dude: Signer
  let dudeAddress: string

  let curveLendingTriCryptoAdapter: CurveLendingTriCryptoAdapter

  let testAdapterSwap: TestAdapterSwap

  // Test Values
  const TOKENS: IERC20[] = []

  const CHAIN = 43114
  const DEX = "curve"

  // const TOKENS_DECIMALS = [6, 8, 18]
  const TOKENS_DECIMALS = [18, 6, 6, 4, 14]
  const tokenSymbols = ["DAIe", "USDCe", "USDTe", "WBTCe", "WETHe"]

  const DIRECT_SWAP_SUPPORTED = true

  const range = (n) => Array.from({ length: n }, (value, key) => key)
  const ALL_TOKENS = range(tokenSymbols.length)

  const AMOUNTS = [
    [8, 4567, 255000],
    [8, 4567, 255000],
    [8, 4567, 255000],
    [1, 1000, 50000],
    [10, 10000, 500000],
  ]
  const AMOUNTS_BIG = [
    [1337000, 5010020, 10200300],
    [1337000, 5010020, 10200300],
    [1337000, 5010020, 10200300],
    [480000, 2022000, 4200000],
    [4790000, 23145000, 42000000],
  ]
  const CHECK_UNDERQUOTING = false

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
          for (let amount of amounts[i]) {
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
        let amount = getBigNumber(1e12, decimals)
        await setBalance(ownerAddress, tokenAddress, amount, storageSlot)
        expect(await getUserTokenBalance(ownerAddress, token)).to.eq(amount)
      }

      const curveAdapterFactory = await ethers.getContractFactory(
        "CurveLendingTriCryptoAdapter",
      )

      curveLendingTriCryptoAdapter = (await curveAdapterFactory.deploy(
        "CurveBaseAdapter",
        config[CHAIN][DEX].tricrypto,
        160000,
        DIRECT_SWAP_SUPPORTED,
        config[CHAIN][DEX].aave,
      )) as CurveLendingTriCryptoAdapter

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
      expect(await curveLendingTriCryptoAdapter.pool()).to.eq(
        config[CHAIN][DEX].tricrypto,
      )

      for (let i in TOKENS) {
        let token = TOKENS[i].address
        expect(await curveLendingTriCryptoAdapter.isPoolToken(token))
        expect(await curveLendingTriCryptoAdapter.tokenIndex(token)).to.eq(+i)
      }
    })

    it("Swap fails if transfer amount is too little", async () => {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let depositAddress = await curveLendingTriCryptoAdapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.sub(1))
      await expect(
        curveLendingTriCryptoAdapter.swap(
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
      let depositAddress = await curveLendingTriCryptoAdapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.add(extra))
      await curveLendingTriCryptoAdapter.swap(
        amount,
        TOKENS[0].address,
        TOKENS[1].address,
        ownerAddress,
      )

      await expect(
        curveLendingTriCryptoAdapter
          .connect(dude)
          .recoverERC20(TOKENS[0].address, extra),
      ).to.be.revertedWith("Ownable: caller is not the owner")

      await expect(() =>
        curveLendingTriCryptoAdapter.recoverERC20(TOKENS[0].address, extra),
      ).to.changeTokenBalance(TOKENS[0], owner, extra)
    })

    it("Anyone can take advantage of overprovided swap tokens", async () => {
      // WETHe -> WBTCe
      let tokenFrom = 4
      let tokenTo = 3
      let amount = getBigNumber(10, 18)
      let extra = getBigNumber(42, 17)
      let depositAddress = await curveLendingTriCryptoAdapter.depositAddress(
        TOKENS[tokenFrom].address,
        TOKENS[tokenTo].address,
      )
      TOKENS[tokenFrom].transfer(depositAddress, amount.add(extra))
      await curveLendingTriCryptoAdapter.swap(
        amount,
        TOKENS[tokenFrom].address,
        TOKENS[tokenTo].address,
        ownerAddress,
      )

      let swapQuote = await curveLendingTriCryptoAdapter.query(
        extra,
        TOKENS[tokenFrom].address,
        TOKENS[tokenTo].address,
      )

      // .add(1) to reflect underquoting by 1
      await expect(() =>
        curveLendingTriCryptoAdapter
          .connect(dude)
          .swap(
            extra,
            TOKENS[tokenFrom].address,
            TOKENS[tokenTo].address,
            dudeAddress,
          ),
      ).to.changeTokenBalance(TOKENS[tokenTo], dude, swapQuote.add(1))
    })

    it("Only Owner can rescue GAS from Adapter", async () => {
      let amount = 42690
      await expect(() =>
        owner.sendTransaction({
          to: curveLendingTriCryptoAdapter.address,
          value: amount,
        }),
      ).to.changeEtherBalance(curveLendingTriCryptoAdapter, amount)

      await expect(
        curveLendingTriCryptoAdapter.connect(dude).recoverGAS(amount),
      ).to.be.revertedWith("Ownable: caller is not the owner")

      await expect(() =>
        curveLendingTriCryptoAdapter.recoverGAS(amount),
      ).to.changeEtherBalances(
        [curveLendingTriCryptoAdapter, owner],
        [-amount, amount],
      )
    })
  })

  describe("Adapter Swaps", () => {
    it("Swaps between tokens [120 small-medium swaps]", async () => {
      await testAdapter(curveLendingTriCryptoAdapter, ALL_TOKENS, ALL_TOKENS, 2)
    })

    it("Swaps between tokens [120 big-ass swaps]", async () => {
      await testAdapter(
        curveLendingTriCryptoAdapter,
        ALL_TOKENS,
        ALL_TOKENS,
        2,
        AMOUNTS_BIG,
      )
    })
  })
})
