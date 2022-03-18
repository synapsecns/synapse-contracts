import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { CHAIN_ID } from "../utils/network"
import { includes } from "lodash"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get, execute } = deployments
  const { deployer } = await getNamedAccounts()

  if (includes([CHAIN_ID.BOBA], await getChainId())) {
    const deployResultFactory = await deploy("BonusChefFactory", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
    })

    if (deployResultFactory.newlyDeployed) {
      // args are [MiniChef, poolId, rewardsDistribution, governance]
      await execute(
        "BonusChefFactory",
        { from: deployer, log: true },
        "deploy",
        (
          await get("MiniChefV21")
        ).address,
        0,
        (
          await get("DevMultisig")
        ).address,
        (
          await get("DevMultisig")
        ).address,
      )

      await execute(
        "BonusChefFactory",
        { from: deployer, log: true },
        "deploy",
        (
          await get("MiniChefV21")
        ).address,
        1,
        (
          await get("DevMultisig")
        ).address,
        (
          await get("DevMultisig")
        ).address,
      )
    }
  }
}

export default func
func.tags = ["MiniChefV21"]
