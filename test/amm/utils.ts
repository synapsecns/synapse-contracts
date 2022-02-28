import { Swap } from "../../build/typechain"
import { BigNumber } from "ethers"

/**
 * gets pool balances for a swap contract and a given number of tokens in a pool
 * @param swap
 * @param numOfTokens
 */
export async function getPoolBalances(
  swap: Swap,
  numOfTokens: number,
): Promise<BigNumber[]> {
  const balances: BigNumber[] = []

  for (let i = 0; i < numOfTokens; i++) {
    balances.push(await swap.getTokenBalance(i))
  }
  return balances
}
