//@ts-nocheck
import { ethers, network } from "hardhat"
import { BigNumber } from "@ethersproject/bignumber"
import { MAX_UINT256, getUserTokenBalance } from "../../utils"
import { ERC20, SynapseBridge } from "../../../build/typechain"

export async function prepare(thisObject, contracts) {
  for (let indexFrom in contracts) {
    let contract = contracts[indexFrom]
    thisObject[contract] = await ethers.getContractFactory(contract)
  }
  thisObject.signers = await ethers.getSigners()
  thisObject.owner = thisObject.signers[0]
  thisObject.dude = thisObject.signers[1]
  thisObject.ownerAddress = thisObject.owner.address
  thisObject.dudeAddress = thisObject.dude.address
}

export async function deploy(thisObject, contracts) {
  for (let contract of contracts) {
    // console.log(contract)
    thisObject[contract[0]] = await contract[1].deploy(...(contract[2] || []))
    await thisObject[contract[0]].deployed()
  }
}

export async function prepareAdapterFactories(thisObject, adapter) {
  await prepare(thisObject, ["TestAdapterSwap", adapter.contract])
}

export async function setupAdapterTests(
  thisObject,
  config,
  adapter,
  tokenSymbols: Array<string>,
  maxUnderQuote: Number,
  amount,
) {
  await deploy(thisObject, [
    ["testAdapterSwap", thisObject.TestAdapterSwap, [maxUnderQuote]],
  ])
  await deploy(thisObject, [
    ["adapter", thisObject[adapter.contract], [...adapter.params]],
  ])

  thisObject.tokenDecimals = await setupTokens(
    thisObject.ownerAddress,
    config,
    tokenSymbols,
    amount,
  )

  thisObject.tokens = []

  for (let symbol of tokenSymbols) {
    let token = await ethers.getContractAt(
      "contracts/amm/SwapCalculator.sol:IERC20Decimals",
      config.assets[symbol],
    )
    thisObject.tokens.push(token)
    await token.approve(thisObject.testAdapterSwap.address, MAX_UINT256)
  }
}

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

let currentKappa = 0
const VALIDATOR = "0x230A1AC45690B9Ae1176389434610B9526d2f21b"

export async function setSynapseBalance(
  userAddress: string,
  tokenAddress: string,
  amount: BigNumber,
  bridgeAddress: string,
) {
  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [VALIDATOR],
  })
  let validator = await ethers.getSigner(VALIDATOR)
  let bridge = (await ethers.getContractAt(
    "SynapseBridge",
    bridgeAddress,
  )) as SynapseBridge

  let token = (await ethers.getContractAt(
    "@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20",
    tokenAddress,
  )) as ERC20

  let balance = await token.balanceOf(userAddress)

  if (amount.gt(balance)) {
    await bridge
      .connect(validator)
      .mint(
        userAddress,
        tokenAddress,
        amount.sub(balance),
        0,
        ethers.utils.hexZeroPad(ethers.utils.hexlify(currentKappa), 32),
      )
    currentKappa += 1
  }
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
  thisObject,
  tokensFrom: Array<number>,
  tokensTo: Array<number>,
  times: Number,
  amounts,
  checkUnderquoting: Boolean,
) {
  let swapsAmount = 0
  let amountNum = amounts[0].length
  let tokens = thisObject.tokens
  for (let _iter in range(times))
    for (let indexAmount in range(amountNum))
      for (let indexTo of tokensTo) {
        let tokenTo = tokens[indexTo]
        for (let indexFrom of tokensFrom) {
          if (indexFrom == indexTo) {
            continue
          }

          let tokenFrom = tokens[indexFrom]
          swapsAmount++
          await thisObject.testAdapterSwap.testSwap(
            thisObject.adapter.address,
            amounts[indexFrom][indexAmount],
            tokenFrom.address,
            tokenTo.address,
            checkUnderquoting,
            swapsAmount,
          )
        }
      }
  console.log("Swaps: %s", swapsAmount)
}

export function range(num: Number): Array<Number> {
  return Array.from({ length: num }, (value, key) => key)
}

export async function getAmounts(
  config,
  address: String,
  tokensSymbols: Array<string>,
  percents: Array<Number>,
): Promise<Array<BigNumber>> {
  let balances = {}
  for (let token of tokensSymbols) {
    balances[token] = await getUserTokenBalance(
      address,
      await ethers.getContractAt(
        "contracts/amm/SwapCalculator.sol:IERC20Decimals",
        config.assets[token],
      ),
    )
  }
  return tokensSymbols.map(function (token) {
    return percents.map(function (percentage) {
      return balances[token].mul(percentage).div(1000)
    })
  })
}

export async function forkChain(apiUrl: String, blockNumber: Number) {
  await network.provider.request({
    method: "hardhat_reset",
    params: [
      {
        forking: {
          jsonRpcUrl: apiUrl,
          blockNumber: blockNumber,
        },
      },
    ],
  })
}

export function getSwapsAmount(len: Number) {
  return len * (len - 1)
}

export async function doSwap(
  thisObject,
  amount,
  indexFrom: Number,
  indexTo: number,
  extra = 0,
  user = "owner",
  doDeposit = true,
): Promise {
  let signer = thisObject[user]
  let depositAddress = await thisObject.adapter.depositAddress(
    thisObject.tokens[indexFrom].address,
    thisObject.tokens[indexTo].address,
  )

  if (doDeposit) {
    thisObject.tokens[indexFrom]
      .connect(signer)
      .transfer(depositAddress, amount.add(extra))
  }

  return thisObject.adapter
    .connect(signer)
    .swap(
      amount,
      thisObject.tokens[indexFrom].address,
      thisObject.tokens[indexTo].address,
      signer.address,
    )
}
