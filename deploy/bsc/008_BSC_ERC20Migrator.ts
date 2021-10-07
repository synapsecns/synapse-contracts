import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()
  if ((await getChainId()) === '56') {
    await deploy('ERC20Migrator', {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get('NerveToken')).address,
        (await get('SynapseToken')).address,
      ]
    })

    await deploy('MigratorBridgeZap', {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true
    })
  }
}
export default func
func.tags = ['ERC20Migrator']
