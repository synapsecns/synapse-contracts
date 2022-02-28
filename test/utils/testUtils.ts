import { BigNumber, Bytes, ContractFactory, Signer, providers } from "ethers"
import { ethers, network } from "hardhat"

import { Artifact } from "hardhat/types"
import { BytesLike } from "@ethersproject/bytes"
import { Contract } from "@ethersproject/contracts"
import { ERC20 } from "../../build/typechain/ERC20"
import { Swap } from "../../build/typechain/Swap"

export const MAX_UINT256 = ethers.constants.MaxUint256
export const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"

export enum TIME {
  SECONDS = 1,
  DAYS = 86400,
  WEEKS = 604800,
}

// Contract calls

export async function getUserTokenBalances(
  address: string | Signer,
  tokens: ERC20[],
): Promise<BigNumber[]> {
  const balanceArray: BigNumber[] = []

  if (address instanceof Signer) {
    address = await address.getAddress()
  }

  for (const token of tokens) {
    balanceArray.push(await token.balanceOf(address))
  }

  return balanceArray
}

export async function getUserTokenBalance(
  address: string | Signer,
  token: ERC20,
): Promise<BigNumber> {
  if (address instanceof Signer) {
    address = await address.getAddress()
  }
  return token.balanceOf(address)
}

// EVM methods

export async function forceAdvanceOneBlock(timestamp?: number): Promise<any> {
  const params = timestamp ? [timestamp] : []
  return ethers.provider.send("evm_mine", params)
}

export async function setTimestamp(timestamp: number): Promise<any> {
  return forceAdvanceOneBlock(timestamp)
}

export async function increaseTimestamp(timestampDelta: number): Promise<any> {
  await ethers.provider.send("evm_increaseTime", [timestampDelta])
  return forceAdvanceOneBlock()
}

export async function setNextTimestamp(timestamp: number): Promise<any> {
  const chainId = (await ethers.provider.getNetwork()).chainId

  switch (chainId) {
    case 31337: // buidler evm
      return ethers.provider.send("evm_setNextBlockTimestamp", [timestamp])
    case 1337: // ganache
    default:
      return setTimestamp(timestamp)
  }
}

export async function getCurrentBlockTimestamp(): Promise<number> {
  const block = await ethers.provider.getBlock("latest")
  return block.timestamp
}

export async function impersonateAccount(
  address: string,
): Promise<providers.JsonRpcSigner> {
  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [address],
  })

  return ethers.provider.getSigner(address)
}

export async function asyncForEach<T>(
  array: Array<T>,
  callback: (item: T, index: number) => void,
): Promise<void> {
  for (let index = 0; index < array.length; index++) {
    await callback(array[index], index)
  }
}
