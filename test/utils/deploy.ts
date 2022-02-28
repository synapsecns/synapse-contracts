// Workaround for linking libraries not yet working in buidler-waffle plugin
// https://github.com/nomiclabs/buidler/issues/611
import { Artifact } from "hardhat/types"
import { Bytes, ContractFactory, Signer } from "ethers"
import { Contract } from "@ethersproject/contracts"
import { ethers } from "hardhat"
import { Context } from "mocha"

/**
 * linkBytecode links an artifact to the deployed bytecode
 * @param artifact contract being deployed
 * @param libraries required libraries of the artifact
 */
export function linkBytecode(
  artifact: Artifact,
  libraries: Record<string, string>,
): string | Bytes {
  let bytecode = artifact.bytecode

  for (const [, fileReferences] of Object.entries(artifact.linkReferences)) {
    // Workarounds for https://github.com/nomiclabs/buidler/issues/611
    for (const [libName, fixups] of Object.entries(fileReferences)) {
      const addr = libraries[libName]
      if (addr === undefined) {
        continue
      }

      for (const fixup of fixups) {
        bytecode =
          bytecode.substr(0, 2 + fixup.start * 2) +
          addr.substr(2) +
          bytecode.substr(2 + (fixup.start + fixup.length) * 2)
      }
    }
  }

  return bytecode
}

/**
 * deployContractWithLibraries deploys a contract and any neccesary bytcode
 * @param signer
 * @param artifact
 * @param libraries
 * @param args
 */
export async function deployContractWithLibraries(
  signer: Signer,
  artifact: Artifact,
  libraries: Record<string, string>,
  args?: Array<unknown>,
): Promise<Contract> {
  const lib = (await ethers.getContractFactory(
    artifact.abi,
    linkBytecode(artifact, libraries),
    signer,
  )) as ContractFactory

  if (args) {
    return lib.deploy(...args)
  } else {
    return lib.deploy()
  }
}

/**
 * deploys a number of contracts for testing
 * @param context: this in the context of a chai test
 * @param contracts: contracts to deploy, as an array
 */
export async function deploy(context: Context, contracts) {
  for (let i in contracts) {
    let contract = contracts[i]
    context[contract[0]] = await contract[1].deploy(...(contract[2] || []))
    await context[contract[0]].deployed()
  }
}
