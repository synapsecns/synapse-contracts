import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()

  await deploy("MetaSwap", {
    from: deployer,
    log: true,
    contract: "MetaSwap",
    skipIfAlreadyDeployed: true,
    libraries: {
      SwapUtils: (await get("SwapUtils")).address,
      MetaSwapUtils: (await get("MetaSwapUtils")).address,
      AmplificationUtils: (await get("AmplificationUtils")).address,
    },
  })
}

export default func
func.tags = ["MetaSwap"]
