//@ts-nocheck
import { BigNumber, Signer } from "ethers"
import { MAX_UINT256, getUserTokenBalance } from "../../amm/testUtils"
import { solidity } from "ethereum-waffle"
import { deployments } from "hardhat"

import { TestAdapterSwap } from "../build/typechain/TestAdapterSwap"
import { IERC20 } from "../../../build/typechain/IERC20"
import { CurveTriCryptoAdapter } from "../../../build/typechain/CurveTriCryptoAdapter"
import chai from "chai"
import { getBigNumber } from "../../bridge/utilities"
import { setBalance } from "../utils/helpers"

import config from "../../config.json"

chai.use(solidity)
const { expect } = chai

describe("Curve TriCrypto Adapter", async () => {
  let signers: Array<Signer>

  let owner: Signer
  let ownerAddress: string
  let dude: Signer
  let dudeAddress: string

  let curveTriCryptoAdapter: CurveTriCryptoAdapter

  let testAdapterSwap: TestAdapterSwap

  // Test Values
  const TOKENS: IERC20[] = []

  // USDT, WBTC, WETH
  // const TOKENS_DECIMALS = [6, 8, 18]
  const TOKENS_DECIMALS = [6, 4, 14]
  const STORAGE = [2, 0, 3]

  const AMOUNTS = [
    [8, 1001, 96420, 1337000],
    [1, 1000, 20000, 480000],
    [10, 2500, 210000, 4790000]
  ]
  const AMOUNTS_BIG = [
    [10200300, 50100200, 100300400],
    [4200000, 20220000, 44000000],
    [42000000, 231450000, 426900000]
  ]
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

      let poolTokens = [
        config[1].assets.USDT,
        config[1].assets.WBTC,
        config[1].assets.WETH,
      ]

      for (var i = 0; i < poolTokens.length; i++) {
        let token = (await ethers.getContractAt(
          "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol:IERC20",
          poolTokens[i],
        )) as IERC20
        TOKENS.push(token)

        let amount = getBigNumber(1e12, TOKENS_DECIMALS[i])
        await setBalance(ownerAddress, poolTokens[i], amount, STORAGE[i])
        expect(await getUserTokenBalance(ownerAddress, token)).to.eq(amount)
      }

      const curveAdapterFactory = await ethers.getContractFactory(
        "CurveTriCryptoAdapter",
      )

      curveTriCryptoAdapter = (await curveAdapterFactory.deploy(
        "CurveBaseAdapter",
        config[1].curve.tricrypto,
        160000,
      )) as CurveTriCryptoAdapter

      for (let token of TOKENS) {
        await token.approve(testAdapterSwap.address, MAX_UINT256)
      }
    },
  )

  before(async () => {
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: process.env.ALCHEMY_API,
            blockNumber: 14000000, // 2022-01-13
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
      expect(await curveTriCryptoAdapter.pool()).to.eq(config[1].curve.tricrypto)

      for (let i in TOKENS) {
        let token = TOKENS[i].address
        expect(await curveTriCryptoAdapter.isPoolToken(token))
        expect(await curveTriCryptoAdapter.tokenIndex(token)).to.eq(+i)
      }
    })

    it("Swap fails if transfer amount is too little", async () => {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let depositAddress = await curveTriCryptoAdapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.sub(1))
      await expect(
        curveTriCryptoAdapter.swap(
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
      let depositAddress = await curveTriCryptoAdapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.add(extra))
      await curveTriCryptoAdapter.swap(
        amount,
        TOKENS[0].address,
        TOKENS[1].address,
        ownerAddress,
      )

      await expect(
        curveTriCryptoAdapter
          .connect(dude)
          .recoverERC20(TOKENS[0].address, extra),
      ).to.be.revertedWith("Ownable: caller is not the owner")

      await expect(() =>
        curveTriCryptoAdapter.recoverERC20(TOKENS[0].address, extra),
      ).to.changeTokenBalance(TOKENS[0], owner, extra)
    })

    it("Anyone can take advantage of overprovided swap tokens", async () => {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let extra = getBigNumber(42, TOKENS_DECIMALS[0] - 1)
      let depositAddress = await curveTriCryptoAdapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.add(extra))
      await curveTriCryptoAdapter.swap(
        amount,
        TOKENS[0].address,
        TOKENS[1].address,
        ownerAddress,
      )

      let swapQuote = await curveTriCryptoAdapter.query(
        extra,
        TOKENS[0].address,
        TOKENS[1].address,
      )

      // .add(1) to reflect underquoting by 1
      await expect(() =>
        curveTriCryptoAdapter
          .connect(dude)
          .swap(extra, TOKENS[0].address, TOKENS[1].address, dudeAddress),
      ).to.changeTokenBalance(TOKENS[1], dude, swapQuote.add(1))
    })

    it("Only Owner can rescue GAS from Adapter", async () => {
      let amount = 42690
      await expect(() =>
        owner.sendTransaction({
          to: curveTriCryptoAdapter.address,
          value: amount,
        }),
      ).to.changeEtherBalance(curveTriCryptoAdapter, amount)

      await expect(
        curveTriCryptoAdapter.connect(dude).recoverGAS(amount),
      ).to.be.revertedWith("Ownable: caller is not the owner")

      await expect(() =>
        curveTriCryptoAdapter.recoverGAS(amount),
      ).to.changeEtherBalances([curveTriCryptoAdapter, owner], [-amount, amount])
    })
  })

  describe("Adapter Swaps", () => {
    it("Swaps between tokens [120 small-medium swaps]", async () => {
      await testAdapter(curveTriCryptoAdapter, [0, 1, 2], [0, 1, 2], 5)
    })

    it("Swaps between tokens [90 big-ass swaps]", async () => {
      await testAdapter(
        curveTriCryptoAdapter,
        [0, 1, 2],
        [0, 1, 2],
        5,
        AMOUNTS_BIG,
      )
    })
  })
})
