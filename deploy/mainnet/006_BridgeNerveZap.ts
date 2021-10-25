import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()
  if ((await getChainId()) === '1') {
    await deploy('NerveBridgeZap', {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get('WETH')).address,
        (await get('NerveUSDPool')).address,
        (await get('SynapseBridge')).address,
      ],
    })
  }
}
export default func
func.tags = ['NerveBridgeZap']
