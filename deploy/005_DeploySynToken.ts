import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { deploy, get, execute, getOrNull } = deployments
  const { deployer } = await getNamedAccounts()

    if (await getOrNull('SynapseToken') == null) {  
        await execute(
            "SynapseERC20Factory",
            { from: deployer, log: true },
            "deploy",
            (await get("SynapseERC20")).address,
            "Synapse",
            "SYN",
            "18",
            (await get("DevMultisig")).address,
      )
    }
}

export default func
func.tags = ['SynapseERC20Factory']
