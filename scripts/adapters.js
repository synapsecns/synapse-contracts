const { AbiCoder } = require("@ethersproject/abi")
const { isAddress, isBytesLike } = require("ethers/lib/utils")
const fs = require("fs")
const { isNumber, isBoolean } = require("lodash")

const args = process.argv.slice(2)

if (args.length != 2) {
  console.log(`please supply the correct parameters:
    chainId fn
  `)
  process.exit(1)
}

const chainId = args[0]
const fn = args[1]
let rawData = fs.readFileSync(fn)
let data = JSON.parse(rawData)

let abiCoder = new AbiCoder()
let adapters = []
for (let dex in data[chainId]) {
  let pools = data[chainId][dex]
  for (let poolName in pools) {
    let pool = pools[poolName]
    // encode constructor params
    let types = []
    for (let param of pool["params"]) {
      if (isAddress(param)) {
        types.push("address")
      } else if (isBytesLike(param)) {
        types.push("bytes32")
      } else if (isNumber(param)) {
        types.push("uint256")
      } else if (isBoolean(param)) {
        types.push("bool")
      } else {
        types.push("string")
      }
    }
    let params = abiCoder.encode(types, pool["params"])

    // encode info for each Adapter:
    // contractName, adapterName, constructorParams, tokens, isUnderquoting
    adapters.push(
      abiCoder.encode(
        ["string", "string", "bytes", "string[]", "bool"],
        [
          pool["contract"],
          pool["params"][0],
          params,
          pool["tokens"],
          pool["underquote"],
        ],
      ),
    )
  }
}
console.log(abiCoder.encode(["bytes[]"], [adapters]))
