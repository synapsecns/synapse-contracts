import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()
  if ((await getChainId()) === '56') {
    await deploy('NerveMetaBridgeZap', {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get('BSCNerveNUSDMetaPoolDeposit')).address,
        (await get('SynapseBridge')).address,
      ],
    })
  }

  if ((await getChainId()) === '137') {
    await deploy('NerveMetaBridgeZap', {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get('PolygonNerveNUSDMetaPoolDeposit')).address,
        (await get('SynapseBridge')).address,
      ],
    })
  }
}
export default func
func.tags = ['NerveMetaBridgeZap']
