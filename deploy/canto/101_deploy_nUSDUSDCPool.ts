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
  let nUSDUSDCPool = await getOrNull("nUSDUSDCPool");
  if (nUSDUSDCPool) {
    log(`reusing "nUSDPoolV3" at ${nUSDUSDCPool}`);
  } else {
    // Constructor arguments
    let TOKEN_ADDRESSES = [];
    let TOKEN_DECIMALS = [];
    let INITIAL_A = 800;

    TOKEN_ADDRESSES = [(await get("nUSD")).address, (await get("USDC")).address];
    TOKEN_DECIMALS = [18, 6];

    const LP_TOKEN_NAME = "nUSD NOTE LP";
    const LP_TOKEN_SYMBOL = "nUSD-LP";
    const SWAP_FEE = 1e6; // 4bps
    const ADMIN_FEE = 6000000000;

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
    await save("nUSDUSDCPool", {
      abi: (await get("SwapFlashLoan")).abi,
      address: usdSwapAddress,
    });

    const lpTokenAddress = (await read("nUSDUSDCPool", "swapStorage")).lpToken;
    log(`USD pool LP Token at ${lpTokenAddress}`);

    await save("nUSDUSDCPool-LPToken", {
      abi: (await get("LPToken")).abi,
      address: lpTokenAddress,
    });

    const currentOwner = await read("nUSDUSDCPool", "owner");

    if (currentOwner == deployer) {
      log(
        `transferring the ownership of "nUSDUSDCPool" to the multisig: ${
          (await get("DevMultisig")).address
        }`
      );
      await execute(
        "nUSDUSDCPool",
        { from: deployer, log: true },
        "transferOwnership",
        (
          await get("DevMultisig")
        ).address
      );
    } else if (currentOwner == (await get("DevMultisig")).address) {
      log(`"nUSDUSDCPool" is already owned by the multisig: ${(await get("DevMultisig")).address}`);
    }
  }
};

export default func;
func.tags = ["nUSDUSDCPool"];
func.dependencies = ["SwapUtils", "SwapDeployer", "SwapFlashLoan"];
