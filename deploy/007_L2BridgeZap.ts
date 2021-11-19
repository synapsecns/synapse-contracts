import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()
  if ((await getChainId()) === "56") {
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

  if ((await getChainId()) === "137") {
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

  if ((await getChainId()) === "250") {
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



  if ((await getChainId()) === "288") {
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


  if ((await getChainId()) === "1666600000") {
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

  if ((await getChainId()) === "43114") {
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

  if ((await getChainId()) === "42161") {
    await deploy("L2BridgeZap", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get("WETH")).address,
        (await get("nETHPool")).address,
        (await get("nETH")).address,
        (await get("nUSDPoolV2")).address,
        (await get("nUSD")).address,
        (await get("SynapseBridge")).address,
      ],
    })
  }
}
export default func
func.tags = ["L2BridgeZap"]
