import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { includes } from "lodash"
import { CHAIN_ID } from "../utils/network"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get, execute, catchUnknownSigner } = deployments
  const { deployer } = await getNamedAccounts()

  if ((includes([CHAIN_ID.GOERLI, CHAIN_ID.FUJI], await getChainId()))) {
    await deploy("SynapseBridge", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      proxy: {
        owner: deployer,
        proxyContract: "OpenZeppelinTransparentProxy",
      },
    })

    // await execute(
    //   "SynapseBridge",
    //   { from: deployer, log: true },
    //   "initialize",
    // )

  } else {
    await catchUnknownSigner(
      deploy("SynapseBridge", {
        from: deployer,
        log: true,
        skipIfAlreadyDeployed: true,
        proxy: {
          owner: deployer,
          // owner: (await get("TimelockController")).address,
          proxyContract: "OpenZeppelinTransparentProxy",
        },
      }),
    )
  }
}
export default func
func.tags = ["SynapseBridge"]
