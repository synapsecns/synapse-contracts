import { BigNumber } from "ethers"

export const BASE_TEN = 10

/**
 * gets a big number from an amount expressed as an int
 * @param amount: as a javascript number
 * @param decimals: number of decimals used in the big int. Defaults to 18
 */
export function getBigNumber(amount: any, decimals: number = 18): BigNumber {
  return BigNumber.from(amount).mul(BigNumber.from(BASE_TEN).pow(decimals))
}
