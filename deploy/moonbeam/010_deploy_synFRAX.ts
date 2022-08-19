import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { getChainId } from "hardhat"
import { CHAIN_ID } from "../../utils/network"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { deploy, get, getOrNull, execute, log } = deployments
  const { deployer } = await getNamedAccounts()

  if (await getChainId() != CHAIN_ID.MOONBEAM){
    return
  }

  let synFRAX = await getOrNull("synFRAX")
  if (synFRAX) {
    log(`reusing 'synFRAX' at ${synFRAX.address}`)
  } else {
    await deploy("synFRAX", {
      contract: "SynapseERC20",
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
    })
    await execute(
      "synFRAX",
      { from: deployer, log: true },
      "initialize",
      "Synapse FRAX",
      "synFRAX",
      "18",
      deployer,
    )

    await execute(
        "synFRAX",
        { from: deployer, log: true },
        "grantRole",
        "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",
        (
          await get("SynapseBridge")
        ).address,
      )

      await execute(
        "synFRAX",
        { from: deployer, log: true },
        "grantRole",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        (
          await get("DevMultisig")
        ).address,
      )

      await execute(
        "synFRAX",
        { from: deployer, log: true },
        "renounceRole",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        deployer,
      )
  }
}
export default func
func.tags = ["synFRAX"]
