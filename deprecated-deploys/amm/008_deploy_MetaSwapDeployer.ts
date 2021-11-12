import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { get, deploy, execute, read } = deployments
  const { deployer } = await getNamedAccounts()

  // await deploy("MetaSwapDeployer", {
  //   from: deployer,
  //   log: true,
  //   skipIfAlreadyDeployed: true,
  //   args: [
  //     (await get("MetaSwap")).address,
  //     (await get("MetaSwapDeposit")).address,
  //   ],
  // })

  // const currentOwner = await read("MetaSwapDeployer", "owner")
  // const multisig = (await get("DevMultisig")).address

  // if (
  //   (await getChainId()) == '1' &&
  //   currentOwner != multisig
  // ) {
  //   await execute(
  //     "MetaSwapDeployer",
  //     { from: deployer, log: true },
  //     "transferOwnership",
  //     multisig,
  //   )
  // }
}
export default func
func.tags = ["MetaSwapDeployer"]
