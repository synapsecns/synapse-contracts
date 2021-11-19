import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { CHAIN_ID } from "../utils/network"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get, execute, getOrNull, log, save } = deployments
  const { deployer } = await getNamedAccounts()

  if (
    (await getChainId()) != CHAIN_ID.MOONRIVER) {
  if ((await getOrNull("nUSD")) == null) {
    const receipt = await execute(
      "SynapseERC20Factory",
      { from: deployer, log: true },
      "deploy",
      (
        await get("SynapseERC20")
      ).address,
      "nUSD",
      "nUSD",
      "18",
      (
        await get("DevMultisig")
      ).address,
    )

  //   const newTokenEvent = receipt?.events?.find(
  //     (e: any) => e["event"] == "SynapseERC20Created",
  //   )
  //   const tokenAddress = newTokenEvent["args"]["contractAddress"]
  //   log(`deployed nUSD token at ${tokenAddress}`)

  //   await save("nUSD", {
  //     abi: (await get("SynapseToken")).abi, // Generic ERC20 ABI
  //     address: tokenAddress,
  //   })
  // }
}
}

export default func
func.tags = ["SynapseERC20Factory"]
