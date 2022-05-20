import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, get, getOrNull, execute, log } = deployments;
  const { deployer } = await getNamedAccounts();

  // let nETH = await getOrNull("nETH");
  // if (nETH) {
  //     log(`reusing 'nETH' at ${nETH.address}`)
  // } else {
  //   await deploy('nETH', {
  //       contract: 'SynapseERC20',
  //       from: deployer,
  //       log: true,
  //       skipIfAlreadyDeployed: true,
  //     })

  //     await execute(
  //             "nETH",
  //             { from: deployer, log: true },
  //             "initialize",
  //             "nETH",
  //             "nETH",
  //             "18",
  //             (
  //               await get("DevMultisig")
  //             ).address,
  //           )
  // }
};
export default func;
func.tags = ["SynapseERC20"];
