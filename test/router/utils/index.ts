import { ethers } from "hardhat"
import { BigNumber } from "ethers"

export const BASE_TEN = 10

export async function prepare(thisObject, contracts) {
  for (let i in contracts) {
    let contract = contracts[i]
    thisObject[contract] = await ethers.getContractFactory(contract)
  }
  thisObject.signers = await ethers.getSigners()
  thisObject.owner = thisObject.signers[0]
  thisObject.dude = thisObject.signers[1]
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
