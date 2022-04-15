import { DeployFunction } from "hardhat-deploy/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { CHAIN_ID } from "../../utils/network"

import ADAPTERS_ALL from "../../test/adapters/adapters.json"
import CONFIG_ALL from "../../test/config.json"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, execute, get, read } = deployments
  const { deployer } = await getNamedAccounts()

  const adaptersToDeploy = {
    curve: ["tricrypto", "usdc"],
    synapse: ["eth", "usd"],
    uniswap: ["traderjoe", "pangolin"],
  }

  if ((await getChainId()) === CHAIN_ID.AVALANCHE) {
    await deploy("Router", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [(await get("WAVAX")).address],
    })

    await deploy("Quoter", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [((await get("Router")).address), 4],
    })

    let deployedAdapters = []

    for (let dex in adaptersToDeploy) {
      for (let pool of adaptersToDeploy[dex]) {
        let adapter = ADAPTERS_ALL[CHAIN_ID.AVALANCHE][dex][pool]
        let adapterName = adapter.params[0]
        await deploy(adapterName, {
          from: deployer,
          log: true,
          skipIfAlreadyDeployed: true,
          contract: adapter.contract,
          args: [...adapter.params],
        })

        deployedAdapters.push((await get(adapterName)).address)
      }
    }

    await execute(
      "Router",
      { from: deployer, log: true },
      "grantRole",
      await read("Router", "ADAPTERS_STORAGE_ROLE"),
      (
        await get("Quoter")
      ).address,
    )

    await execute(
      "Quoter",
      { from: deployer, log: true },
      "setAdapters",
      deployedAdapters,
    )

    let tokens = CONFIG_ALL[CHAIN_ID.AVALANCHE].assets

    let trustedTokens = [
      tokens.DAIe,
      tokens.USDCe,
      tokens.USDTe,
      tokens.USDC,

      tokens.WAVAX,
      tokens.WETHe,
      tokens.WBTCe,
    ]

    await execute(
      "Quoter",
      { from: deployer, log: true },
      "setTokens",
      trustedTokens,
    )
  }
}
export default func
func.tags = ["RouterTesting"]
