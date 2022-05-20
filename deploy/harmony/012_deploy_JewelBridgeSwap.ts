import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CHAIN_ID } from "../../utils/network";
import { includes } from "lodash";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy, get } = deployments;
  const { deployer } = await getNamedAccounts();
  if (includes([CHAIN_ID.HARMONY], await getChainId())) {
    await deploy("JewelBridgeSwap", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: ["0x72Cb10C6bfA5624dD07Ef608027E366bd690048F", (await get("synJEWEL")).address],
    });
  }
};
export default func;
func.tags = ["JewelBridgeSwap"];
