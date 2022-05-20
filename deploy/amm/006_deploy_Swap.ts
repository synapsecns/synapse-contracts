import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { includes } from "lodash";
import { CHAIN_ID } from "../../utils/network";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy, get } = deployments;
  const { libraryDeployer } = await getNamedAccounts();
  if (!includes([CHAIN_ID.DFK], await getChainId())) {
    await deploy("Swap", {
      from: libraryDeployer,
      log: true,
      libraries: {
        SwapUtils: (await get("SwapUtils")).address,
        AmplificationUtils: (await get("AmplificationUtils")).address,
      },
      skipIfAlreadyDeployed: true,
    });
  }
};
export default func;
func.tags = ["Swap"];
func.dependencies = ["AmplificationUtils", "SwapUtils"];
