import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CHAIN_ID } from "../utils/network";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { get, execute, getOrNull, log, save } = deployments;
  const { deployer } = await getNamedAccounts();

  if (await getChainId() == CHAIN_ID.KLAYTN_TESTNET) {
    if ((await getOrNull("JEWEL")) == null) {
      const receipt = await execute(
        "SynapseERC20Factory",
        { from: deployer, log: true },
        "deploy",
        (
          await get("SynapseERC20")
        ).address,
        "JEWEL",
        "JEWEL",
        "18",
        deployer
        // (
        //   await get("DevMultisig")
        // ).address,
      );

      const newTokenEvent = receipt?.events?.find((e: any) => e["event"] == "SynapseERC20Created");
      const tokenAddress = newTokenEvent["args"]["contractAddress"];
      log(`deployed JEWEL token at ${tokenAddress}`);

      await save("JEWEL", {
        abi: (await get("SynapseERC20")).abi, // Generic ERC20 ABI
        address: tokenAddress,
      });


    }
  }
};

export default func;
func.tags = ["JEWEL_TESTNET"];

