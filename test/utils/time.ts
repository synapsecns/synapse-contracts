import { BigNumberish } from "ethers"

const { ethers } = require("hardhat")

const { BigNumber } = ethers

/**
 * advanceBlock advances the block number by one
 */
export async function advanceBlock() {
  return ethers.provider.send("evm_mine", [])
}

/**
 * advances the block number to a future block. If the block number is greater then the current block
 * nothing is done
 * @param blockNumber - block number to advance to
 */
export async function advanceBlockTo(blockNumber) {
  for (let i = await ethers.provider.getBlockNumber(); i < blockNumber; i++) {
    await advanceBlock()
  }
}

/**
 * increase time by an amount
 * @param amount - amount to increase time by
 */
export async function increaseTime(amount) {
  await ethers.provider.send("evm_increaseTime", [amount.toNumber()])
  await advanceBlock()
}

/**
 * latestTime returns the latest time
 */
export async function latestTime(): Promise<BigNumberish> {
  const block = await ethers.provider.getBlock("latest")
  return BigNumber.from(block.timestamp)
}

/**
 * advances time by amount and increments the block number by 1
 * @param time
 */
export async function advanceTimeAndBlock(time) {
  await advanceTime(time)
  await advanceBlock()
}

/**
 * advances time by amount
 * @param amount - amount to increase time by
 */
export async function advanceTime(amount) {
  await ethers.provider.send("evm_increaseTime", [amount])
}

export const duration = {
  /**
   * get a seconds value from an int
   * @param val to convert to seconds
   */
  seconds: function (val: any): BigNumberish {
    return BigNumber.from(val)
  },
  /**
   * get a minutes value from an int
   * @param val to convert to minutes
   */
  minutes: function (val: any): BigNumberish {
    return BigNumber.from(val).mul(this.seconds("60"))
  },
  /**
   * get a hours value from an int
   * @param val to convert to hours
   */
  hours: function (val: any): BigNumberish {
    return BigNumber.from(val).mul(this.minutes("60"))
  },
  /**
   * get a days value from an int
   * @param val to convert to daysa
   */
  days: function (val: any): BigNumberish {
    return BigNumber.from(val).mul(this.hours("24"))
  },
  /**
   * get a weeks value from an int
   * @param val to convert to weeks
   */
  weeks: function (val): BigNumberish {
    return BigNumber.from(val).mul(this.days("7"))
  },
  /**
   * get a years value from an int
   * @param val to convert to years
   */
  years: function (val): BigNumberish {
    return BigNumber.from(val).mul(this.days("365"))
  },
}
