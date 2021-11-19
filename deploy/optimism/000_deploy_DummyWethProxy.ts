import { DeployFunction } from "hardhat-deploy/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { CHAIN_ID } from "../../utils/network"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()

  if ((await getChainId()) === CHAIN_ID.OPTIMISM) {
    await deploy("DummyWethProxy", {
        from: deployer,
        log: true,
        skipIfAlreadyDeployed: true,
        proxy: {
            owner: deployer,
            proxyContract: "OpenZeppelinTransparentProxy",
        },
    })
}
}
export default func
func.tags = ["DummyWeth"]
