import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import {includes} from "lodash";
import { CHAIN_ID } from "../../utils/network"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, execute, getOrNull } = deployments
  const { libraryDeployer } = await getNamedAccounts()

  if (!(includes([CHAIN_ID.DFK], await getChainId()))) {
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
}
export default func
func.tags = ["LPToken"]
