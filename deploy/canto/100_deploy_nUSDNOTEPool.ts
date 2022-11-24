import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CHAIN_ID } from "../../utils/network";
import { includes } from "lodash";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { execute, get, getOrNull, log, read, save } = deployments;
  const { deployer } = await getNamedAccounts();

  if ((await getChainId()) != CHAIN_ID.CANTO) {
    return;
  }

  // Manually check if the pool is already deployed
  let nUSDNOTEPool = await getOrNull("nUSDNOTEPool");
  if (nUSDNOTEPool) {
    log(`reusing "nUSDPoolV3" at ${nUSDNOTEPool}`);
  } else {
    // Constructor arguments
    let TOKEN_ADDRESSES = [];
    let TOKEN_DECIMALS = [];
    let INITIAL_A = 70;

    TOKEN_ADDRESSES = [(await get("nUSD")).address, (await get("NOTE")).address];
    TOKEN_DECIMALS = [18, 18];

    const LP_TOKEN_NAME = "nUSD NOTE LP";
    const LP_TOKEN_SYMBOL = "nUSD-LP";
    const SWAP_FEE = 1e6; // 4bps
    const ADMIN_FEE = 8000000000;

    const receipt = await execute(
      "SwapDeployer",
      { from: deployer, log: true },
      "deploy",
      (
        await get("SwapFlashLoan")
      ).address,
      TOKEN_ADDRESSES,
      TOKEN_DECIMALS,
      LP_TOKEN_NAME,
      LP_TOKEN_SYMBOL,
      INITIAL_A,
      SWAP_FEE,
      ADMIN_FEE,
      (
        await get("LPToken")
      ).address
    );

    const newPoolEvent = receipt?.events?.find((e: any) => e["event"] == "NewSwapPool");
    const usdSwapAddress = newPoolEvent["args"]["swapAddress"];
    log(`deployed USD pool clone (targeting "SwapFlashLoan") at ${usdSwapAddress}`);
    await save("nUSDNOTEPool", {
      abi: (await get("SwapFlashLoan")).abi,
      address: usdSwapAddress,
    });

    const lpTokenAddress = (await read("nUSDNOTEPool", "swapStorage")).lpToken;
    log(`USD pool LP Token at ${lpTokenAddress}`);

    await save("nUSDNOTEPool-LPToken", {
      abi: (await get("LPToken")).abi,
      address: lpTokenAddress,
    });

    const currentOwner = await read("nUSDNOTEPool", "owner");

    if (currentOwner == deployer) {
      log(
        `transferring the ownership of "nUSDNOTEPool" to the multisig: ${
          (await get("DevMultisig")).address
        }`
      );
      await execute(
        "nUSDNOTEPool",
        { from: deployer, log: true },
        "transferOwnership",
        (
          await get("DevMultisig")
        ).address
      );
    } else if (currentOwner == (await get("DevMultisig")).address) {
      log(`"nUSDNOTEPool" is already owned by the multisig: ${(await get("DevMultisig")).address}`);
    }
  }
};

export default func;
func.tags = ["nUSDNOTEPool"];
func.dependencies = ["SwapUtils", "SwapDeployer", "SwapFlashLoan"];
