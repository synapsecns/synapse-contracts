import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CHAIN_ID } from "../utils/network";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy, get, getOrNull, log, read, save } = deployments;
  const { deployer } = await getNamedAccounts();

  if ((await getChainId()) === CHAIN_ID.CANTO) {
    // SwapWrapper doesn't require any params and doesn't have an owner
    await deploy("CantoSwapWrapper", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
    });
  }
};

export default func;
func.tags = ["SwapWrapper"];