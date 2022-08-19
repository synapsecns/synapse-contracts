import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CHAIN_ID } from "../../utils/network";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy, get } = deployments;
  const { deployer } = await getNamedAccounts();
  if ((await getChainId()) === CHAIN_ID.MAINNET) {
    await deploy("PoolConfig", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
    });
  }
};
export default func;
func.tags = ["PoolConfig"];
