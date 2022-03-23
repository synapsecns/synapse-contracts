import { ethers } from "hardhat"
import { BigNumber, ContractFactory } from "ethers"
import { Context } from "mocha"
import {
  IERC20,
  Swap,
  UniswapV2Factory,
  SynapseBaseAdapter,
  IUniswapV2Pair,
} from "../../../build/typechain"
import { MAX_UINT256 } from "../../utils"

export const BASE_TEN = 10

export async function prepare(thisObject, contracts) {
  for (let i in contracts) {
    let contract = contracts[i]
    thisObject[contract] = await ethers.getContractFactory(contract)
  }
  thisObject.signers = await ethers.getSigners()
  thisObject.owner = thisObject.signers[0]
  thisObject.dude = thisObject.signers[1]

  thisObject.ownerAddress = await thisObject.signers[0].getAddress()
  thisObject.dudeAddress = await thisObject.signers[1].getAddress()
}

export async function deploy(thisObject, contracts) {
  for (let i in contracts) {
    let contract = contracts[i]
    thisObject[contract[0]] = await contract[1].deploy(...(contract[2] || []))
    await thisObject[contract[0]].deployed()
  }
}

export function getBigNumber(amount, decimals = 18) {
  return BigNumber.from(amount).mul(BigNumber.from(BASE_TEN).pow(decimals))
}

export async function setupSynapsePool(
  thisObject: Context,
  swapFactory: ContractFactory,
  adapterFactory: ContractFactory,
  lpTokenAddress: string,
  pool: string,
  adapter: string,
  tokens: Array<IERC20>,
  decimals: Array<number>,
  a: number,
  fee: number,
  amount: number,
  swapGasEstimate: number = 150000,
) {
  let swap = (await swapFactory.deploy()) as Swap
  await swap.initialize(
    tokens.map(function (token) {
      return token.address
    }),
    decimals,
    "LP Token",
    "LP",
    a,
    fee,
    6 * 10 ** 9,
    lpTokenAddress,
  )
  thisObject[pool] = swap

  let basePoolAdapter = (await adapterFactory.deploy(
    "BasePoolAdapter",
    swap.address,
    swapGasEstimate,
  )) as SynapseBaseAdapter
  thisObject[adapter] = basePoolAdapter

  let amounts = []

  for (let index in tokens) {
    await tokens[index].approve(swap.address, MAX_UINT256)
    amounts.push(getBigNumber(amount, decimals[index]))
  }

  await swap.addLiquidity(amounts, 0, MAX_UINT256)
}

export async function setupUniswapPool(
  thisObject: Context,
  uniswapFactory: UniswapV2Factory,
  tokenA: IERC20,
  amountA: number,
  decimalsA: number,
  tokenB: IERC20,
  amountB: number,
  decimalsB: number,
) {
  await uniswapFactory.createPair(tokenA.address, tokenB.address)
  let pairAddress = await uniswapFactory.getPair(tokenA.address, tokenB.address)

  // provide liquidity
  await tokenA.transfer(pairAddress, getBigNumber(amountA, decimalsA))
  await tokenB.transfer(pairAddress, getBigNumber(amountB, decimalsB))
  let pair = (await ethers.getContractAt(
    "contracts/router/helper/uniswap/interfaces/IUniswapV2Pair.sol:IUniswapV2Pair",
    pairAddress,
  )) as IUniswapV2Pair
  await pair.mint(thisObject.ownerAddress)
}

export async function setupUniswapAdapters(
  thisObject: Context,
  uniswapAdapterFactory: ContractFactory,
  factories: Array<string>,
  adapters: Array<string>,
  swapGasEstimate: number = 50000,
  fee: number = 30,
) {
  for (let index in factories) {
    let factoryName = factories[index]
    thisObject[adapters[index]] = await uniswapAdapterFactory.deploy(
      factoryName,
      thisObject[factoryName].address,
      swapGasEstimate,
      fee,
    )
  }
}

export function areDiffResults(
  pathA: Array<string>,
  adaptersA: Array<string>,
  pathB: Array<string>,
  adaptersB: Array<string>,
): boolean {
  if (pathA.length != pathB.length || adaptersA.length != adaptersB.length) {
    return true
  }
  for (let index in pathA) {
    if (pathA[index] !== pathB[index]) {
      return true
    }
  }
  for (let index in adaptersA) {
    if (adaptersA[index] !== adaptersB[index]) {
      return true
    }
  }
  return false
}
