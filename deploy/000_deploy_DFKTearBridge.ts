import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CHAIN_ID } from "../utils/network";
import { includes } from "lodash";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy, get, execute } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();
  const TearBridgeConfig = {
    [CHAIN_ID.DFK_TESTNET]: {
      gaia: "0x5829A860284f4c800a60ccDa4157e8dde0C32D30",
    },
    [CHAIN_ID.HARMONY_TESTNET]: {
      gaia: "0xf0e28E7c46F307954490fB1134c8D437e23D55fb",
    },
    [CHAIN_ID.DFK]: {
      gaia: "0x58E63A9bbb2047cd9Ba7E6bB4490C238d271c278",
    },
    [CHAIN_ID.HARMONY]: {
      gaia: "0x24eA0D436d3c2602fbfEfBe6a16bBc304C963D04",
    },
  };
  if (
    includes(
      [CHAIN_ID.DFK_TESTNET, CHAIN_ID.HARMONY_TESTNET, CHAIN_ID.DFK, CHAIN_ID.HARMONY],
      chainId
    )
  ) {
    const deployResult = await deploy("TearBridge", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [(await get("MessageBus")).address, TearBridgeConfig[chainId].gaia],
    });

    if (deployResult.newlyDeployed) {
      await execute("TearBridge", { from: deployer, log: true }, "setMsgGasLimit", "800000");
    }
  }
};
export default func;
func.tags = ["DFKTearBridge"];
func.dependencies = ["Messaging"];
