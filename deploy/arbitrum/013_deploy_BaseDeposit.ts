import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { CHAIN_ID } from "../../utils/network";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy, get } = deployments;
  const { deployer } = await getNamedAccounts();

  if ((await getChainId()) === CHAIN_ID.ARBITRUM) {
    await deploy("BaseSwapDeposit", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [(await get("ETHPool")).address],
    });
  }
};
export default func;
func.tags = ["BaseSwapDeposit"];
