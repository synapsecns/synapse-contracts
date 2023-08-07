import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CHAIN_ID } from "../../utils/network";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { execute, get, getOrNull, log, read, save } = deployments;
  const { deployer } = await getNamedAccounts();

  // Manually check if the pool is already deployed
  let ETHPool = await getOrNull("ETHPool");
  if (ETHPool) {
    log(`reusing "ETHPool" at ${ETHPool.address}`);
  } else if ((await getChainId()) != CHAIN_ID.BASE && (await getChainId()) != CHAIN_ID.HARDHAT) {
    log(`Not Base or Hardhat`);
  } else {
    // Constructor arguments
    const TOKEN_ADDRESSES = [(await get("nETH")).address, (await get("WETH")).address];
    const TOKEN_DECIMALS = [18, 18];
    const LP_TOKEN_NAME = "nETH-LP";
    const LP_TOKEN_SYMBOL = "nETH-LP";
    const INITIAL_A = 800;
    const SWAP_FEE = 10e6; // 4bps
    const ADMIN_FEE = 9000000000;

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
    log(`deployed ETH pool clone (targeting "SwapFlashLoan") at ${usdSwapAddress}`);
    await save("ETHPool", {
      abi: (await get("SwapFlashLoan")).abi,
      address: usdSwapAddress,
    });

    const lpTokenAddress = (await read("ETHPool", "swapStorage")).lpToken;
    log(`ETH pool LP Token at ${lpTokenAddress}`);

    await save("ETHPoolLPToken", {
      abi: (await get("WETH")).abi, // Generic ERC20 ABI
      address: lpTokenAddress,
    });
  }
};
export default func;
func.tags = ["BASE_ETHPool"];
func.dependencies = ["SwapUtils", "SwapDeployer", "SwapFlashLoan", "USDPoolTokens"];
