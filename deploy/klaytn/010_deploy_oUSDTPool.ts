import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CHAIN_ID } from "../../utils/network";
import { includes } from "lodash";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { execute, get, getOrNull, log, read, save } = deployments;
  const { deployer } = await getNamedAccounts();

  // Manually check if the pool is already deployed
  let oUSDTPool = await getOrNull("oUSDTPool");
  if (oUSDTPool) {
    log(`reusing "oUSDTPool" at ${oUSDTPool.address}`);
  } else if (includes([CHAIN_ID.KLATYN], await getChainId())) {
    // Constructor arguments
    const TOKEN_ADDRESSES = [(await get("USDT")).address, (await get("oUSDT")).address];
    const TOKEN_DECIMALS = [6, 6];
    const LP_TOKEN_NAME = "oUSDT-LP";
    const LP_TOKEN_SYMBOL = "oUSDT-LP";
    const INITIAL_A = 1000;
    const SWAP_FEE = 2e6; // 2bps
    const ADMIN_FEE = 6e9; // 60%

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
    log(`deployed oUSDT pool clone (targeting "SwapFlashLoan") at ${usdSwapAddress}`);
    await save("oUSDTPool", {
      abi: (await get("SwapFlashLoan")).abi,
      address: usdSwapAddress,
    });

    const lpTokenAddress = (await read("oUSDTPool", "swapStorage")).lpToken;
    log(`oUSDT pool LP Token at ${lpTokenAddress}`);

    await save("oUSDTPoolLPToken", {
      abi: (await get("DAI")).abi, // Generic ERC20 ABI
      address: lpTokenAddress,
    });

    const currentOwner = await read("oUSDTPool", "owner");

    if (currentOwner == deployer) {
      log(
        `transferring the ownership of "oUSDTPool" to the multisig: ${
          (await get("DevMultisig")).address
        }`
      );
      await execute(
        "oUSDTPool",
        { from: deployer, log: true },
        "transferOwnership",
        (
          await get("DevMultisig")
        ).address
      );
    } else if (currentOwner == (await get("DevMultisig")).address) {
      log(`"oUSDTPool" is already owned by the multisig: ${(await get("DevMultisig")).address}`);
    }
  }
};
export default func;
func.tags = ["oUSDTPool"];
func.dependencies = ["SwapUtils", "SwapDeployer", "SwapFlashLoan", "USDPoolTokens"];
