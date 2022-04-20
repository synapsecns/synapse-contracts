import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import {CHAIN_ID} from "../utils/network";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()
  if ((await getChainId()) === CHAIN_ID.BSC) {
    await deploy("L2BridgeZap", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        "0x0000000000000000000000000000000000000000",
        (await get("nUSDPoolV2")).address,
        (await get("nUSD")).address,
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
        (await get("SynapseBridge")).address,
      ],
    })
  }

  if ((await getChainId()) === CHAIN_ID.POLYGON) {
    await deploy("L2BridgeZap", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        "0x0000000000000000000000000000000000000000",
        (await get("nUSDPoolV2")).address,
        (await get("nUSD")).address,
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
        (await get("SynapseBridge")).address,
      ],
    })
  }

  if ((await getChainId()) === CHAIN_ID.AURORA) {
    await deploy("L2BridgeZap", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        "0x0000000000000000000000000000000000000000",
        (await get("nUSDPoolV2")).address,
        (await get("nUSD")).address,
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
        (await get("SynapseBridge")).address,
      ],
    })
  }

  if ((await getChainId()) === CHAIN_ID.FANTOM) {
    await deploy("L2BridgeZap", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        "0x0000000000000000000000000000000000000000",
        (await get("nUSDPoolV3")).address,
        (await get("nUSD")).address,
        (await get("ETHPool")).address,
        (await get("nETH")).address,
        (await get("SynapseBridge")).address,
      ],
    })
  }

  if ((await getChainId()) === "1284") {
    await deploy("L2BridgeZap", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
        (await get("SynapseBridge")).address,
      ],
    })
  }

  if ((await getChainId()) === CHAIN_ID.DFK) {
    await deploy("L2BridgeZap", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
        (await get("SynapseBridge")).address,
      ],
    })
  }


  if ((await getChainId()) === CHAIN_ID.METIS) {
    await deploy("L2BridgeZap", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        "0x0000000000000000000000000000000000000000",
        (await get("nUSDPoolV3")).address,
        (await get("nUSD")).address,
        (await get("ETHPool")).address,
        (await get("nETH")).address,
        (await get("SynapseBridge")).address,
      ],
    })
  }


  if ((await getChainId()) === CHAIN_ID.CRONOS) {
    await deploy("L2BridgeZap", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
        (await get("SynapseBridge")).address,
      ],
    })
  }



  if ((await getChainId()) === CHAIN_ID.MOONRIVER) {
    await deploy("L2BridgeZap", {
      contract: "MoonriverBridgeZap",
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get("WMOVR")).address,
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
        (await get("SynapseBridge")).address,
      ],
    })
  }

  if ((await getChainId()) === CHAIN_ID.BOBA) {
    await deploy("L2BridgeZap", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get("WETH")).address,
        (await get("ETHPool")).address,
        (await get("nETH")).address,
        (await get("nUSDPoolV2")).address,
        (await get("nUSD")).address,
        (await get("SynapseBridge")).address,
      ],
    })
  }


  if ((await getChainId()) === CHAIN_ID.OPTIMISM) {
    await deploy("L2BridgeZap", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get("WETH")).address,
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
        (await get("nUSDPoolV3")).address,
        (await get("nUSD")).address,
        (await get("SynapseBridge")).address,
      ],
      gasLimit: 5000000,
    })
  }


  if ((await getChainId()) === CHAIN_ID.HARMONY) {
    await deploy("L2BridgeZap", {
      contract: 'HarmonyBridgeZap',
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        "0x0000000000000000000000000000000000000000",
        (await get("nUSDPoolV2")).address,
        (await get("nUSD")).address,
        (await get("ETHPool")).address,
        (await get("nETH")).address,
        (await get("JewelBridgeSwap")).address,
        (await get("synJEWEL")).address,
        (await get("BridgedAVAXPool")).address,
        (await get("AVAX")).address,
        (await get("SynapseBridge")).address,
      ],
    })
  }

  if ((await getChainId()) === CHAIN_ID.AVALANCHE) {
    await deploy("L2BridgeZap", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get("WAVAX")).address,
        (await get("AaveSwapWrapper")).address,
        (await get("nETH")).address,
        (await get("nUSDPoolV2")).address,
        (await get("nUSD")).address,
        (await get("SynapseBridge")).address,
      ],
      gasLimit: 5000000
    })
  }

  if ((await getChainId()) === CHAIN_ID.ARBITRUM) {
    await deploy("L2BridgeZap", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get("WETH")).address,
        (await get("nETHPool")).address,
        (await get("nETH")).address,
        (await get("nUSDPoolV3")).address,
        (await get("nUSD")).address,
        (await get("SynapseBridge")).address,
      ],
    })
  }
}
export default func
func.tags = ["L2BridgeZap"]
func.dependencies = ["DummyWeth", "WETH"]
