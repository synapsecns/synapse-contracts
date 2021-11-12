import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { deploy, execute, getOrNull } = deployments
  const { libraryDeployer } = await getNamedAccounts()

  let LPToken = await getOrNull("LPToken")
  if (!LPToken) {
    await deploy("LPToken", {
      from: libraryDeployer,
      log: true,
      skipIfAlreadyDeployed: true,
    })

    await execute(
      "LPToken",
      { from: libraryDeployer, log: true },
      "initialize",
      "Synapse LP Token (Target)",
      "synapseLPTokenTarget",
    )
  }
}
export default func
func.tags = ["LPToken"]
