import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, get, execute } = deployments;
  const { deployer } = await getNamedAccounts();

  const deployResult = await deploy("MiniChefV2", {
    from: deployer,
    log: true,
    skipIfAlreadyDeployed: true,
    args: [(await get("SynapseToken")).address],
  });

  if (deployResult.newlyDeployed) {
    await execute(
      "MiniChefV2",
      { from: deployer, log: true },
      "transferOwnership",
      (
        await get("DevMultisig")
      ).address,
      true,
      false
    );
  }
};

export default func;
func.tags = ["MiniChefV2"];
