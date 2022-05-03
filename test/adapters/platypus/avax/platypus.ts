import { Signer } from "ethers"
import { MAX_UINT256, getUserTokenBalance } from "../../../utils"
import { solidity } from "ethereum-waffle"
import { ethers } from "hardhat"

import {
  TestAdapterSwap,
  PlatypusAdapter,
  ERC20,
} from "../../../../build/typechain"

import chai from "chai"
import { getBigNumber } from "../../../bridge/utilities"
import { forkChain, setBalance } from "../../utils/helpers"

import config from "../../../config.json"

chai.use(solidity)
const { expect } = chai

describe("Platypus Adapter", async function () {
  let signers: Array<Signer>

  let owner: Signer
  let ownerAddress: string
  let dude: Signer
  let dudeAddress: string

  let adapter: PlatypusAdapter

  let testAdapterSwap: TestAdapterSwap

  const CHAIN = 43114
  const DEX = "platypus"

  const TOKENS: ERC20[] = []
  const TOKENS_DECIMALS = []

  const AMOUNTS = [42, 5100200]
  const CHECK_UNDERQUOTING = true

  const range = (n) => Array.from({ length: n }, (value, key) => key)

  const tokenSymbols = ["USDTe", "USDCe", "DAIe", "USDC", "USDT"]

  const baseTokens = [0]
  const allTokens = range(tokenSymbols.length)

  async function testAdapter(
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
    console.log("Swaps: %s", swapsAmount)
  }

  async function setupTest() {
    TOKENS.length = 0
    signers = await ethers.getSigners()
    owner = signers[0]
    ownerAddress = await owner.getAddress()
    dude = signers[1]
    dudeAddress = await dude.getAddress()

    const adapterFactory = await ethers.getContractFactory("PlatypusAdapter")

    adapter = (await adapterFactory.deploy(
      "PlatypusAdapter",
      160000,
      config[CHAIN][DEX].pool,
    )) as PlatypusAdapter

    const testFactory = await ethers.getContractFactory("TestAdapterSwap")

    testAdapterSwap = (await testFactory.deploy(0)) as TestAdapterSwap

    for (let symbol of tokenSymbols) {
      let tokenAddress = config[CHAIN].assets[symbol]
      let storageSlot = config[CHAIN].slot[symbol]
      let token = (await ethers.getContractAt(
        "@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20",
        tokenAddress,
      )) as ERC20
      TOKENS.push(token)
      let decimals = await token.decimals()
      TOKENS_DECIMALS.push(decimals)

      let amount = getBigNumber(1e12, decimals)
      await setBalance(ownerAddress, tokenAddress, amount, storageSlot)
      expect(await getUserTokenBalance(owner, token)).to.be.eq(amount)

      token.approve(testAdapterSwap.address, MAX_UINT256)
    }
  }

  before(async function () {
    // 2022-03-26
    await forkChain(process.env.AVAX_API, 12590000)
  })

  beforeEach(async function () {
    await setupTest()
  })

  describe("Sanity checks", function () {
    it("Platypus Adapter is properly set up", async function () {
      expect(await adapter.pool()).to.eq(config[CHAIN][DEX].pool)
    })

    it("Swap fails if transfer amount is too little", async function () {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let depositAddress = await adapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.sub(1))
      await expect(
        adapter.swap(
          amount,
          TOKENS[0].address,
          TOKENS[1].address,
          ownerAddress,
        ),
      ).to.be.reverted
    })

    it("Only Owner can rescue overprovided swap tokens", async function () {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let extra = getBigNumber(42, TOKENS_DECIMALS[0] - 1)
      let depositAddress = await adapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.add(extra))
      await adapter.swap(
        amount,
        TOKENS[0].address,
        TOKENS[1].address,
        ownerAddress,
      )

      await expect(
        adapter.connect(dude).recoverERC20(TOKENS[0].address),
      ).to.be.revertedWith("Ownable: caller is not the owner")

      await expect(() =>
        adapter.recoverERC20(TOKENS[0].address),
      ).to.changeTokenBalance(TOKENS[0], owner, extra)
    })

    it("Anyone can take advantage of overprovided swap tokens", async function () {
      let amount = getBigNumber(10, TOKENS_DECIMALS[0])
      let extra = getBigNumber(42, TOKENS_DECIMALS[0] - 1)
      let depositAddress = await adapter.depositAddress(
        TOKENS[0].address,
        TOKENS[1].address,
      )
      TOKENS[0].transfer(depositAddress, amount.add(extra))
      await adapter.swap(
        amount,
        TOKENS[0].address,
        TOKENS[1].address,
        ownerAddress,
      )

      let swapQuote = await adapter.query(
        extra,
        TOKENS[0].address,
        TOKENS[1].address,
      )

      await expect(() =>
        adapter
          .connect(dude)
          .swap(extra, TOKENS[0].address, TOKENS[1].address, dudeAddress),
      ).to.changeTokenBalance(TOKENS[1], dude, swapQuote)
    })

    it("Only Owner can rescue GAS from Adapter", async function () {
      let amount = 42690
      await expect(() =>
        owner.sendTransaction({ to: adapter.address, value: amount }),
      ).to.changeEtherBalance(adapter, amount)

      await expect(adapter.connect(dude).recoverGAS()).to.be.revertedWith(
        "Ownable: caller is not the owner",
      )

      await expect(() => adapter.recoverGAS()).to.changeEtherBalances(
        [adapter, owner],
        [-amount, amount],
      )
    })
  })

  describe("Adapter Swaps", function () {
    it("Swaps and Queries from Base (40 swaps)", async function () {
      await testAdapter(allTokens, allTokens, 1)
    })
  })
})
