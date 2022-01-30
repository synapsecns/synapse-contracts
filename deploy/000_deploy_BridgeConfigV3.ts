import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId} = hre
  const { execute, deploy, get } = deployments
  const { deployer } = await getNamedAccounts()

  if ((await getChainId()) === '137') { 
      const deployResult = await deploy('BridgeConfigV3', {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
    })

    if (deployResult.newlyDeployed) {
      await execute(
        "BridgeConfigV3",
        { from: deployer, log: true },
        "grantRole",
        "0x4370dcf3e42e4d5b773a451bb8390ee8e7308f47681d1414cff87c2ad0512c85",
        "0xb3DAD3C24A861b84fDF380B212662620627D4e15",
      )
    }
  }
}

export default func
func.tags = ['BridgeConfig']
