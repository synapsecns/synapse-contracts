import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { CHAIN_ID } from "../utils/network"

import {DeployUtils} from "./utils";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get, execute, getOrNull, log, save } = deployments
  const { deployer } = await getNamedAccounts()

    if ((await getOrNull("SynapseToken")) == null) {
      const receipt = await execute(
        "SynapseERC20Factory",
        { from: deployer, log: true },
        "deploy",
        (
          await get("SynapseERC20")
        ).address,
        "Synapse",
        "SYN",
        "18",
        deployer,
        // (
        //   await get("DevMultisig")
        // ).address,
      )

      const newTokenEvent = receipt?.events?.find(
        (e: any) => e["event"] == "SynapseERC20Created",
      )
      const tokenAddress = newTokenEvent["args"]["contractAddress"]
      log(`deployed synapse token at ${tokenAddress}`)

      await save("SynapseToken", {
        abi: (await get("SynapseERC20")).abi, // Generic ERC20 ABI
        address: tokenAddress,
      })

      await execute(
        "SynapseToken",
        { from: deployer, log: true },
        "grantRole",
          DeployUtils.Roles.SynapseERC20MinterRole,
        (
          await get("SynapseBridge")
        ).address,
      )

      await execute(
        "SynapseToken",
        { from: deployer, log: true },
        "grantRole",
        DeployUtils.Roles.DefaultAdminRole,
        (
          await get("DevMultisig")
        ).address,
      )

      if ((await getChainId()) !== CHAIN_ID.HARDHAT) {
        await execute(
            "SynapseToken",
            { from: deployer, log: true },
            "renounceRole",
            DeployUtils.Roles.DefaultAdminRole,
            deployer,
        )
      }
    }
}

export default func
func.tags = ["SynapseToken"]
