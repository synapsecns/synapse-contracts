import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { CHAIN_ID } from "../utils/network"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()

  if (
    [CHAIN_ID.FANTOM, CHAIN_ID.HARMONY, CHAIN_ID.MOONRIVER].includes(
      await getChainId(),
    )
  ) {
    const deployResult = await deploy("FraxWrapper", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [(await get("FRAX")).address, (await get("synFRAX")).address],
    })
  }
}

export default func
func.tags = ["FraxWrapper"]
