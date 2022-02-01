import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, get, catchUnknownSigner } = deployments;
  const { deployer, devMultisig } = await getNamedAccounts();

    const
        isTenderly:            boolean = hre.network.name.includes("tenderly"),
        owner:                 string  = isTenderly ? deployer : (await get("TimelockController")).address,
        skipIfAlreadyDeployed: boolean = !isTenderly;

    await catchUnknownSigner(
      deploy("SynapseBridgeV2", {
        from: deployer,
        log: true,
        skipIfAlreadyDeployed,
        proxy: {
          owner,
          proxyContract: "OpenZeppelinTransparentProxy",
        },
      }),
    )
}
export default func
func.tags = ["SynapseBridgeV2"]
