import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { CHAIN_ID } from "../utils/network"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get, execute, getOrNull, log, save } = deployments
  const { deployer } = await getNamedAccounts()

  if (
    (await getChainId()) === CHAIN_ID.ARBITRUM ||
    (await getChainId()) === CHAIN_ID.HARDHAT || 
    (await getChainId()) === CHAIN_ID.BOBA ||
    (await getChainId()) === CHAIN_ID.OPTIMISM || 
    (await getChainId()) === CHAIN_ID.AVALANCHE
  ) {
    if ((await getOrNull("nETH")) == null) {
      const receipt = await execute(
        "SynapseERC20Factory",
        { from: deployer, log: true },
        "deploy",
        (
          await get("SynapseERC20")
        ).address,
        "nETH",
        "nETH",
        "18",
        deployer
      )

      const newTokenEvent = receipt?.events?.find(
        (e: any) => e["event"] == "SynapseERC20Created",
      )
      const tokenAddress = newTokenEvent["args"]["contractAddress"]
      log(`deployed nETH token at ${tokenAddress}`)

      await save("nETH", {
        abi: (await get("SynapseToken")).abi, // Generic ERC20 ABI
        address: tokenAddress,
      })

      await execute("nETH", 
        {from: deployer, log: true },
        "grantRole", 
        "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",
        (
          await get("SynapseBridge")
        ).address,
      )

      await execute("nETH", 
        {from: deployer, log: true },
        "transferOwnership", 
        (
          await get("DevMultisig")
        ).address,
      )
    }
  }
}

export default func
func.tags = ["SynapseERC20Factory"]
