import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { CHAIN_ID } from "../../utils/network";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy, get, read, execute, log } = deployments;
  const { deployer } = await getNamedAccounts();

  if ((await getChainId()) === CHAIN_ID.AVALANCHE) {
    await deploy("AvaxJewelMigration", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
    });

    const currentOwner = await read("AvaxJewelMigration", "owner");

    if (currentOwner == deployer) {
      log(
        `transferring the ownership of "AvaxJewelMigration" to the multisig: ${
          (await get("DevMultisig")).address
        }`
      );
      await execute(
        "AvaxJewelMigration",
        { from: deployer, log: true },
        "transferOwnership",
        (
          await get("DevMultisig")
        ).address
      );
    }
  }
};
export default func;
func.tags = ["AvaxJewelMigration"];
