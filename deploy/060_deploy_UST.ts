import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { CHAIN_ID } from "../utils/network"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get, execute, getOrNull, log, save } = deployments
  const { deployer } = await getNamedAccounts()

  if (
    (await getChainId()) === CHAIN_ID.FANTOM ||
    (await getChainId()) === CHAIN_ID.ARBITRUM ||
    (await getChainId()) === CHAIN_ID.AVALANCHE ||
    (await getChainId()) === CHAIN_ID.POLYGON || 
    (await getChainId()) === CHAIN_ID.MOONBEAM || 
    (await getChainId()) === CHAIN_ID.BSC || 
    (await getChainId()) === CHAIN_ID.MOONRIVER ||
    (await getChainId()) === CHAIN_ID.MAINNET ||
    (await getChainId()) === CHAIN_ID.BOBA || 
    (await getChainId()) === CHAIN_ID.OPTIMISM || 
    (await getChainId()) === CHAIN_ID.AURORA || 
    (await getChainId()) === CHAIN_ID.HARMONY
  ) {
    if ((await getOrNull("UST")) == null) {
      const receipt = await execute(
        "SynapseERC20Factory",
        { from: deployer, log: true },
        "deploy",
        (
          await get("SynapseERC20")
        ).address,
        "TerraUSD",
        "UST",
        "6",
        deployer,
        // (
        //   await get("DevMultisig")
        // ).address,
      )

      const newTokenEvent = receipt?.events?.find(
        (e: any) => e["event"] == "SynapseERC20Created",
      )
      const tokenAddress = newTokenEvent["args"]["contractAddress"]
      log(`deployed UST token at ${tokenAddress}`)

      await save("UST", {
        abi: (await get("SynapseERC20")).abi, // Generic ERC20 ABI
        address: tokenAddress,
      })

      await execute(
        "UST",
        { from: deployer, log: true },
        "grantRole",
        "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",
        (
          await get("SynapseBridge")
        ).address,
      )

      await execute(
        "UST",
        { from: deployer, log: true },
        "grantRole",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        (
          await get("DevMultisig")
        ).address,
      )

      await execute(
        "UST",
        { from: deployer, log: true },
        "renounceRole",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        deployer,
      )
    }
  }
}

export default func
func.tags = ["UST"]
