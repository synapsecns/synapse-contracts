import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import {CHAIN_ID} from "../../utils/network";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId} = hre
  const { execute, deploy, get } = deployments
  const { deployer } = await getNamedAccounts()

  if ((await getChainId()) === CHAIN_ID.MAINNET) {
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
        (await get("DevMultisig")).address,
      )

      await execute(
        "BridgeConfigV3",
        { from: deployer, log: true },
        "grantRole",
        "0x4370dcf3e42e4d5b773a451bb8390ee8e7308f47681d1414cff87c2ad0512c85",
        "0x19EB7D50E97bb8BFFC1Fb60964c29BFA3a706aee",
      )


      await execute(
        "BridgeConfigV3",
        { from: deployer, log: true },
        "grantRole",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        (await get("DevMultisig")).address,
      )

      await execute(
        "BridgeConfigV3",
        { from: deployer, log: true },
        "renounceRole",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        deployer,
      )

    }

  }
}

export default func
func.tags = ['BridgeConfigV3']
