import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, get, getOrNull, execute, log } = deployments;
  const { deployer } = await getNamedAccounts();

  let SynapseToken = await getOrNull("SynapseToken");
  if (SynapseToken) {
    log(`reusing 'SynapseToken' at ${SynapseToken.address}`);
  } else {
    await deploy("SynapseToken", {
      contract: "SynapseERC20",
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
    });
    await execute(
      "SynapseToken",
      { from: deployer, log: true },
      "initialize",
      "Synapse",
      "SYN",
      "18",
      (
        await get("DevMultisig")
      ).address
    );
  }
};
export default func;
func.tags = ["SynapseERC20"];
