import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { CHAIN_ID } from "../utils/network"
import {includes} from "lodash";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get, execute } = deployments
  const { deployer } = await getNamedAccounts()

  if ((includes([CHAIN_ID.BOBA], await getChainId()))) {
    const deployResultZero = await deploy('BonusChef0', {
        contract: "BonusChef",
        from: deployer,
        log: true,
        skipIfAlreadyDeployed: true,
        args: [
        (await get('MiniChefV21')).address,
        0,
        (await get('DevMultisig')).address,
        ],
    })


    if (deployResultZero.newlyDeployed) {
      await execute(
        "BonusChef0",
        { from: deployer, log: true },
        "grantRole",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        (
          await get("DevMultisig")
        ).address,
      )

      await execute(
        "BonusChef0",
        { from: deployer, log: true },
        "grantRole",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        (
          await get("DevMultisig")
        ).address,
      )

      await execute(
        "BonusChef0",
        { from: deployer, log: true },
        "renounceRole",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        deployer,
      )
    }

    const deployResultOne = await deploy('BonusChef1', {
      contract: "BonusChef",
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
      (await get('MiniChefV21')).address,
      0,
      (await get('DevMultisig')).address,
      ],
  })


  if (deployResultOne.newlyDeployed) {
    await execute(
      "BonusChef1",
      { from: deployer, log: true },
      "grantRole",
      "0x0000000000000000000000000000000000000000000000000000000000000000",
      (
        await get("DevMultisig")
      ).address,
    )

    await execute(
      "BonusChef0",
      { from: deployer, log: true },
      "grantRole",
      "0x0000000000000000000000000000000000000000000000000000000000000000",
      (
        await get("DevMultisig")
      ).address,
    )

    await execute(
      "BonusChef0",
      { from: deployer, log: true },
      "renounceRole",
      "0x0000000000000000000000000000000000000000000000000000000000000000",
      deployer,
    )
  }


    }
}

export default func
func.tags = ['MiniChefV21']
