import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { CHAIN_ID } from "../../utils/network";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy, get } = deployments;
  const { deployer } = await getNamedAccounts();

  if ((await getChainId()) === CHAIN_ID.OPTIMISM) {
    await deploy("SwapEthWrapper", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get("WETH")).address,
        (await get("ETHPool")).address,
        (await get("DevMultisig")).address,
      ],
    });
  }
};
export default func;
func.tags = ["SwapEthWrapper"];
