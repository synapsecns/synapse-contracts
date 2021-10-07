import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()
  if ((await getChainId()) === '56') {
    await deploy('TokenDistributor', {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [(await get('SynapseToken')).address],
    })
  }
}
export default func
func.tags = ['PoolConfig']
