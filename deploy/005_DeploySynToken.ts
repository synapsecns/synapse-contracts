import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { deploy, get, execute, getOrNull, log, save } = deployments
  const { deployer } = await getNamedAccounts()

    if (await getOrNull('SynapseToken') == null) {  
        const receipt = await execute(
            "SynapseERC20Factory",
            { from: deployer, log: true },
            "deploy",
            (await get("SynapseERC20")).address,
            "Synapse",
            "SYN",
            "18",
            (await get("DevMultisig")).address,
      )

    const newTokenEvent = receipt?.events?.find(
      (e: any) => e["event"] == "SynapseERC20Created",
    )
    const tokenAddress = newTokenEvent["args"]["contractAddress"]
    log(
      `deployed SynapseToken token at ${tokenAddress}`,
    )

    await save("SynapseToken", {
      abi: (await get("SynapseERC20")).abi, // Generic ERC20 ABI
      address: tokenAddress,
    })    
    }
}

export default func
func.tags = ['SynapseERC20Factory']
