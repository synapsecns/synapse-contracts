import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CHAIN_ID } from "../../utils/network";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy } = deployments;
  const { libraryDeployer } = await getNamedAccounts();

  await deploy("AmplificationUtils", {
    from: libraryDeployer,
    log: true,
    skipIfAlreadyDeployed: true,
  });

  if ((await getChainId()) == CHAIN_ID.HARDHAT) {
    await deploy("AmplificationUtils08", {
      from: libraryDeployer,
      log: true,
      skipIfAlreadyDeployed: true,
    });
  }
};
export default func;
func.tags = ["AmplificationUtils", "AmplificationUtils08"];
