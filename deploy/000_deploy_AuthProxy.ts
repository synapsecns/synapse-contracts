import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get, catchUnknownSigner } = deployments
  const { deployer, devMultisig } = await getNamedAccounts()

  await catchUnknownSigner(
    deploy("BridgeAuthProxy", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
    //   proxy: {
    //     owner: deployer,
    //     proxyContract: "OpenZeppelinTransparentProxy",
    //   },
    }),
  )
}
export default func
func.tags = ["BridgeAuthProxy"]
