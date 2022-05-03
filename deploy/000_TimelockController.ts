import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()

  // await deploy("TimelockController", {
  //   from: deployer,
  //   log: true,
  //   skipIfAlreadyDeployed: true,
  //   args: [
  //     180,
  //     [(await get("DevMultisig")).address],
  //     [(await get("DevMultisig")).address],
  //   ],
  // })
}
export default func
func.tags = ["TimelockController"]
func.dependencies = ["DevMultisig"]
