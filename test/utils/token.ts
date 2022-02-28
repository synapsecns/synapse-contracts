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

/**
 * gets usert token balances for a list of tokens in order they were requested
 * @param address of the user to request balances for
 * @param tokens to get balances of
 */
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

/**
 * getUserTokenBalances gets a users balance for a given token
 * @param address
 * @param token
 */
export async function getUserTokenBalance(
  address: string | Signer,
  token: ERC20,
): Promise<BigNumber> {
  if (address instanceof Signer) {
    address = await address.getAddress()
  }
  return token.balanceOf(address)
}
