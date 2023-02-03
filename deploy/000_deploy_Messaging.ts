import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CHAIN_ID } from "../utils/network";
import { includes } from "lodash";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy, get, execute } = deployments;
  const { deployer } = await getNamedAccounts();
  if (
    includes(
      [
        CHAIN_ID.DFK_TESTNET,
        CHAIN_ID.HARMONY_TESTNET,
        CHAIN_ID.DFK,
        CHAIN_ID.HARMONY,
        CHAIN_ID.FUJI,
        CHAIN_ID.GOERLI,
        CHAIN_ID.KLATYN,
        CHAIN_ID.KLAYTN_TESTNET
      ],
      await getChainId()
    )
  ) {
    const authVerifierDeploy = await deploy("AuthVerifier", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: ["0xAA920f7b9039e556d2442113f1fd339e4927Dd9A"],
    });

    if (
      !includes(
        [
          CHAIN_ID.DFK_TESTNET,
          CHAIN_ID.HARMONY_TESTNET,
          CHAIN_ID.FUJI,
          CHAIN_ID.GOERLI,
          CHAIN_ID.KLAYTN_TESTNET
        ],
        await getChainId()
      )
    ) {
      if (authVerifierDeploy.newlyDeployed) {
        await execute(
          "AuthVerifier",
          { from: deployer, log: true },
          "transferOwnership",
          (
            await get("DevMultisig")
          ).address
        );
      }
    }

    await deploy("GasFeePricing", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [],
    });

    const messageBusDeploy = await deploy("MessageBus", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [(await get("GasFeePricing")).address, (await get("AuthVerifier")).address],
    });

    if (
      !includes(
        [
          CHAIN_ID.DFK_TESTNET,
          CHAIN_ID.HARMONY_TESTNET,
          CHAIN_ID.FUJI,
          CHAIN_ID.GOERLI,
          CHAIN_ID.KLAYTN_TESTNET
        ],
        await getChainId()
      )
    ) {
      if (messageBusDeploy.newlyDeployed) {
        await execute(
          "MessageBus",
          { from: deployer, log: true },
          "transferOwnership",
          (
            await get("DevMultisig")
          ).address
        );
      }
    } 
  }
};

func.tags = ["Messaging"];
export default func;
