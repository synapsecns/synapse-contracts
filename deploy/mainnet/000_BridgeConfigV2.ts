import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId} = hre
  const { execute, deploy, get } = deployments
  const { deployer } = await getNamedAccounts()

  if ((await getChainId()) === '1') { 
      const deployResult = await deploy('BridgeConfigV2', {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
    })

    if (deployResult.newlyDeployed) {
      await execute(
        "BridgeConfig",
        { from: deployer, log: true },
        "grantRole",
        "0x4370dcf3e42e4d5b773a451bb8390ee8e7308f47681d1414cff87c2ad0512c85",
        (await get("DevMultisig")).address,
      )

      await execute(
        "BridgeConfig",
        { from: deployer, log: true },
        "grantRole",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        (await get("DevMultisig")).address,
      )

      await execute(
        "BridgeConfig",
        { from: deployer, log: true },
        "renounceRole",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        deployer,
      )

    }

  }
}

export default func
func.tags = ['BridgeConfig']
