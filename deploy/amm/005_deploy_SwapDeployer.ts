import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { includes } from "lodash";
import { CHAIN_ID } from "../../utils/network";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy, execute, read, get, getOrNull } = deployments;
  const { deployer } = await getNamedAccounts();
  if (!includes([CHAIN_ID.DFK], await getChainId())) {
    if ((await getOrNull("SwapDeployer")) == null) {
      await deploy("SwapDeployer", {
        from: deployer,
        log: true,
        skipIfAlreadyDeployed: true,
      });

      const currentOwner = await read("SwapDeployer", "owner");
      const multisig = (await get("DevMultisig")).address;

      if (currentOwner != multisig) {
        await execute("SwapDeployer", { from: deployer, log: true }, "transferOwnership", multisig);
      }
    }
  }
};
export default func;
func.tags = ["SwapDeployer"];
