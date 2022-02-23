//@ts-nocheck
import { ethers, network } from "hardhat"
import { MAX_UINT256, getUserTokenBalance } from "../../amm/testUtils"
import { getBigNumber } from "../../bridge/utilities"
import { IAdapter } from "../../../build/typechain/IAdapter"

export async function setBalance(
  userAddress,
  tokenAddress,
  amount,
  storage = 0,
) {
  const encode = (types, values) =>
    ethers.utils.defaultAbiCoder.encode(types, values)

  const index = ethers.utils.solidityKeccak256(
    ["uint256", "uint256"],
    [userAddress, storage], // slot = 0 for bridged tokens on Avalanche
  )

  await network.provider.send("hardhat_setStorageAt", [
    tokenAddress,
    index.toString(),
    encode(["uint"], [amount]),
  ])
}

export async function deployAdapter(adapter) {
  const factory = await ethers.getContractFactory(adapter.contract)

  return await factory.deploy(...adapter.params)
}

export async function setupTokens(
  address: String,
  config,
  tokenSymbols: Array<String>,
  tokenAmount,
) {
  const tokenDecimals = []
  for (let symbol of tokenSymbols) {
    let tokenAddress = config.assets[symbol]
    let storageSlot = config.slot[symbol]
    let token = await ethers.getContractAt(
      "contracts/amm/SwapCalculator.sol:IERC20Decimals",
      tokenAddress,
    )
    let decimals = await token.decimals()
    tokenDecimals.push(decimals)
    await setBalance(address, tokenAddress, tokenAmount, storageSlot)
  }
  return tokenDecimals
}

export async function testRunAdapter(
  testAdapterSwap,
  adapter: IAdapter,
  tokensFrom: Array<number>,
  tokensTo: Array<number>,
  times: Number,
  amounts: Array<Number>,
  tokens,
  decimals: Array<Number>,
  checkUnderquoting: Boolean,
  amounts2D = false,
) {
  let _amounts = amounts
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
        if (amounts2D) {
          _amounts = amounts[i]
        }
        for (let amount of _amounts) {
          swapsAmount++
          await testAdapterSwap.testSwap(
            adapter.address,
            getBigNumber(amount, decimalsFrom),
            tokenFrom.address,
            tokenTo.address,
            checkUnderquoting,
            swapsAmount,
          )
        }
      }
    }
}

export function range(num: Number): Array<Number> {
  return Array.from({ length: num }, (value, key) => key)
}

export function getReserves(address: String, tokens) {
  return tokens.map(function (token) {
    return await getUserTokenBalance(
      address, token
    )
  })
}