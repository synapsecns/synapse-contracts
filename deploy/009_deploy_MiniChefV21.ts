import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { CHAIN_ID } from "../utils/network"
import {includes} from "lodash";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get, execute } = deployments
  const { deployer } = await getNamedAccounts()

  if ((includes([CHAIN_ID.BOBA], await getChainId()))) {
    const deployResult = await deploy('MiniChefV21', {
        from: deployer,
        log: true,
        skipIfAlreadyDeployed: true,
        args: [
        (await get('SynapseToken')).address
        ],
    })

    if (deployResult.newlyDeployed) {
      await execute(
        "MiniChefV21",
        { from: deployer, log: true },
        "transferOwnership",
        (await get("DevMultisig")).address,
        true,
        false
      )
    }
    }
}

export default func
func.tags = ['MiniChefV21']
