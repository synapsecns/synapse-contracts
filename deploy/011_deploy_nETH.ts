import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CHAIN_ID } from "../utils/network";
import { includes } from "lodash";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy, get, execute, getOrNull, log, save } = deployments;
  const { deployer } = await getNamedAccounts();

  if (
    includes(
      [
        CHAIN_ID.ARBITRUM,
        CHAIN_ID.HARDHAT,
        CHAIN_ID.BOBA,
        CHAIN_ID.OPTIMISM,
        CHAIN_ID.AVALANCHE,
        CHAIN_ID.HARMONY,
        CHAIN_ID.FANTOM,
        CHAIN_ID.METIS,
        CHAIN_ID.CANTO,
        CHAIN_ID.BASE,
        CHAIN_ID.ZKEVM,
        CHAIN_ID.BLAST,
      ],
      await getChainId()
    )
  ) {
    if ((await getOrNull("nETH")) == null) {
      const receipt = await execute(
        "SynapseERC20Factory",
        { from: deployer, log: true },
        "deploy",
        (
          await get("SynapseERC20")
        ).address,
        "nETH",
        "nETH",
        "18",
        deployer
      );

      const newTokenEvent = receipt?.events?.find((e: any) => e["event"] == "SynapseERC20Created");
      const tokenAddress = newTokenEvent["args"]["contractAddress"];
      log(`deployed nETH token at ${tokenAddress}`);

      await save("nETH", {
        abi: (await get("SynapseERC20")).abi, // Generic ERC20 ABI
        address: tokenAddress,
      });

      await execute(
        "nETH",
        { from: deployer, log: true },
        "grantRole",
        "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",
        (
          await get("SynapseBridge")
        ).address
      );

      await execute(
        "nETH",
        { from: deployer, log: true },
        "grantRole",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        (
          await get("DevMultisig")
        ).address
      );

      await execute(
        "nETH",
        { from: deployer, log: true },
        "renounceRole",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        deployer
      );
    }
  }
};

export default func;
func.tags = ["nETH", "SynapseERC20Factory"];
