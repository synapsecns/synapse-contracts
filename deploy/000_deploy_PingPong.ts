import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CHAIN_ID } from "../utils/network";
import { includes } from "lodash";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy, get } = deployments;
  const { deployer } = await getNamedAccounts();
  if (
    includes(
      [
        CHAIN_ID.DFK_TESTNET,
        CHAIN_ID.HARMONY_TESTNET,
        CHAIN_ID.KLAYTN_TESTNET,
        CHAIN_ID.AVALANCHE,
        CHAIN_ID.FUJI,
        CHAIN_ID.GOERLI,
      ],
      await getChainId()
    )
  ) {
    await deploy("PingPong", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [(await get("MessageBus")).address],
    });
  }
};

func.tags = ["PingPong"];
func.dependencies = ["Messaging"];
export default func;
