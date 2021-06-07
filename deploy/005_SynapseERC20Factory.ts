import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()

  await deploy('SynapseERC20Factory', {
    from: deployer,
    log: true,
    skipIfAlreadyDeployed: true,
  })
}
export default func
func.tags = ['SynapseERC20Factory']
