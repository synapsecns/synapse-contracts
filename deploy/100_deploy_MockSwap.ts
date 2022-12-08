import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CHAIN_ID } from "../utils/network";
import { includes } from "lodash";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy, get, execute } = deployments;
  const { deployer } = await getNamedAccounts();

  if (includes([CHAIN_ID.FANTOM, CHAIN_ID.KLATYN], await getChainId())) {
    await deploy("MockSwap", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
    });
  }
};

export default func;
func.tags = ["MockSwap"];
