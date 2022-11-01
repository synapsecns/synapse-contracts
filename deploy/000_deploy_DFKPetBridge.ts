import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CHAIN_ID } from "../utils/network";
import { includes } from "lodash";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy, execute, get } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();
  const PetBridgeConfig = {
    [CHAIN_ID.DFK]: {
      petcore: "0x1990F87d6BC9D9385917E3EDa0A7674411C3Cd7F",
    },
    [CHAIN_ID.HARMONY]: {
      petcore: "0xAC9AFb5900C8A27B766bCad3A37423DC0F4C22d3",
    },
  };

  // MAINNET
  if (includes([CHAIN_ID.DFK, CHAIN_ID.HARMONY], chainId)) {
    const heroBridgeDeployResult = await deploy("PetBridgeUpgradeable", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [],
      proxy: {
        owner: (await get("DevMultisig")).address,
        proxyContract: "OpenZeppelinTransparentProxy",
      },
    });
    if (heroBridgeDeployResult.newlyDeployed) {
      await execute(
        "PetBridgeUpgradeable",
        { from: deployer, log: true },
        "initialize",
        (
          await get("MessageBus")
        ).address,
        PetBridgeConfig[chainId].petcore
      );

      await execute(
        "PetBridgeUpgradeable",
        { from: deployer, log: true },
        "setMsgGasLimit",
        "800000"
      );
    }
  }
};
export default func;
func.tags = ["DFKPetBridge"];
