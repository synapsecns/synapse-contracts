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
        '0x0000000000000000000000000000000000000000',
        (await get('BSCNerveNUSDMetaPoolDeposit')).address,
        (await get('nUSD')).address,
        '0x0000000000000000000000000000000000000000',
        '0x0000000000000000000000000000000000000000',
        (await get('SynapseBridge')).address,
      ],
      gasLimit: 15000000,
      estimatedGasLimit: 20000000
    })
  }

  if ((await getChainId()) === '137') {
    await deploy('NerveMetaBridgeZap', {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        '0x0000000000000000000000000000000000000000',
        (await get('PolygonNerveNUSDMetaPoolDeposit')).address,
        (await get('nUSD')).address,
        '0x0000000000000000000000000000000000000000',
        '0x0000000000000000000000000000000000000000',
        (await get('SynapseBridge')).address,
      ],
    })
  }

  if ((await getChainId()) === '43114') {
    await deploy('NerveMetaBridgeZap', {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        '0x0000000000000000000000000000000000000000',
        (await get('AvalancheNerveNUSDMetaPoolDeposit')).address,
        (await get('nUSD')).address,
        '0x0000000000000000000000000000000000000000',
        '0x0000000000000000000000000000000000000000',
        (await get('SynapseBridge')).address,
      ],
    })
  }

  if ((await getChainId()) === '42161') {
    await deploy('NerveMetaBridgeZap', {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get('WETH')).address,
        (await get('BaseSwapDeposit')).address,
        (await get('nETH')).address,
        (await get('ArbitrumNervenUSDMetaPoolDeposit')).address,
        (await get('nUSD')).address,
        (await get('SynapseBridge')).address,
      ],
    })
  }

}
export default func
func.tags = ['NerveMetaBridgeZap']
