import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()
  if ((await getChainId()) === '137') {
    await deploy('BridgeConfigV2', {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true
    })
  }
}
export default func
func.tags = ['BridgeConfigV2']
