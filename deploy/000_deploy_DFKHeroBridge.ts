import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CHAIN_ID } from "../utils/network";
import { includes } from "lodash";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy, execute, get } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();
  const HeroBridgeConfig = {
    [CHAIN_ID.DFK_TESTNET]: {
      heroes: "0x3bcaCBeAFefed260d877dbE36378008D4e714c8E",
      auction: "0x846635615609a8dd88eA4A92dA1F1Ba6880a9Eb5",
    },
    [CHAIN_ID.HARMONY_TESTNET]: {
      heroes: "0xC57971c3EC0Fc2450FC5CC9c4398ac08ff09e6ED",
      auction: "0x5f5a567140A4b7A0406f568B152aA4bc3aCda8Ed",
    },
    [CHAIN_ID.DFK]: {
      heroes: "0xEb9B61B145D6489Be575D3603F4a704810e143dF",
      auction: "0x8101CfFBec8E045c3FAdC3877a1D30f97d301209",
    },
    [CHAIN_ID.HARMONY]: {
      heroes: "0x5F753dcDf9b1AD9AabC1346614D1f4746fd6Ce5C",
      auction: "0x65DEA93f7b886c33A78c10343267DD39727778c2",
    },
  };

  // TESTNET
  if (includes([CHAIN_ID.DFK_TESTNET, CHAIN_ID.HARMONY_TESTNET], chainId)) {
    await deploy("HeroBridgeUpgradeable", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [],
      proxy: {
        owner: deployer,
        proxyContract: "OpenZeppelinTransparentProxy",
      },
    });
  }

  // MAINNET
  if (includes([CHAIN_ID.DFK, CHAIN_ID.HARMONY], chainId)) {
    const heroBridgeDeployResult = await deploy("HeroBridgeUpgradeable", {
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
        "HeroBridgeUpgradeable",
        { from: deployer, log: true },
        "initialize",
        (
          await get("MessageBus")
        ).address,
        HeroBridgeConfig[chainId].heroes,
        HeroBridgeConfig[chainId].auction
      );

      await execute(
        "HeroBridgeUpgradeable",
        { from: deployer, log: true },
        "setMsgGasLimit",
        "800000"
      );
    }
  }
};
export default func;
func.tags = ["DFKHeroBridge"];
func.dependencies = ["Messaging"];
