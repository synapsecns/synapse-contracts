import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, execute, read, get } = deployments
  const { deployer } = await getNamedAccounts()

  await deploy("SwapDeployer", {
    from: deployer,
    log: true,
    skipIfAlreadyDeployed: true,
  })

  const currentOwner = await read("SwapDeployer", "owner")
  const multisig = (await get("DevMultisig")).address

    await execute(
      "SwapDeployer",
      { from: deployer, log: true },
      "transferOwnership",
      multisig,
    )
}
export default func
func.tags = ["SwapDeployer"]
