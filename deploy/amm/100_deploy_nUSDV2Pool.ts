import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CHAIN_ID } from "../../utils/network";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { execute, get, getOrNull, log, read, save } = deployments;
  const { deployer } = await getNamedAccounts();

  // Manually check if the pool is already deployed
  let nUSDPoolV2 = await getOrNull("nUSDPoolV2");
  if (
    nUSDPoolV2 ||
    (await getChainId()) === CHAIN_ID.OPTIMISM ||
    (await getChainId()) === CHAIN_ID.MAINNET ||
    (await getChainId()) === CHAIN_ID.MOONBEAM ||
    (await getChainId()) === CHAIN_ID.METIS ||
    (await getChainId()) === CHAIN_ID.CRONOS ||
    (await getChainId()) === CHAIN_ID.DFK
  ) {
    // log(`reusing "nUSDPoolV2" at ${nUSDPoolV2}`)
  } else {
    // Constructor arguments
    let TOKEN_ADDRESSES = [];
    let TOKEN_DECIMALS = [];
    let INITIAL_A = 800;
    if (
      (await getChainId()) === CHAIN_ID.POLYGON ||
      (await getChainId()) === CHAIN_ID.AVALANCHE ||
      (await getChainId()) === CHAIN_ID.HARDHAT ||
      (await getChainId()) === CHAIN_ID.HARMONY
    ) {
      TOKEN_ADDRESSES = [
        (await get("nUSD")).address,
        (await get("DAI")).address,
        (await get("USDC")).address,
        (await get("USDT")).address,
      ];
      TOKEN_DECIMALS = [18, 18, 6, 6];
    }

    if ((await getChainId()) === CHAIN_ID.BSC) {
      TOKEN_ADDRESSES = [
        (await get("nUSD")).address,
        (await get("BUSD")).address,
        (await get("USDC")).address,
        (await get("USDT")).address,
      ];
      TOKEN_DECIMALS = [18, 18, 18, 18];
    }

    if ((await getChainId()) === CHAIN_ID.AURORA) {
      TOKEN_ADDRESSES = [
        (await get("nUSD")).address,
        (await get("USDC")).address,
        (await get("USDT")).address,
      ];
      TOKEN_DECIMALS = [18, 6, 6];
    }

    if ((await getChainId()) === CHAIN_ID.ARBITRUM) {
      TOKEN_ADDRESSES = [
        (await get("nUSD")).address,
        (await get("MIM")).address,
        (await get("USDC")).address,
        (await get("USDT")).address,
      ];
      TOKEN_DECIMALS = [18, 18, 6, 6];
      INITIAL_A = 200;
    }

    if ((await getChainId()) === CHAIN_ID.BOBA) {
      TOKEN_ADDRESSES = [
        (await get("nUSD")).address,
        (await get("DAI")).address,
        (await get("USDC")).address,
        (await get("USDT")).address,
      ];
      TOKEN_DECIMALS = [18, 18, 6, 6];
      INITIAL_A = 200;
    }

    // if (await getChainId() === CHAIN_ID.OPTIMISM) {
    //   TOKEN_ADDRESSES = [
    //     (await get("nUSD")).address,
    //     (await get("DAI")).address,
    //     (await get("USDC")).address,
    //     (await get("USDT")).address,
    //   ]
    //   TOKEN_DECIMALS = [18, 18, 6, 6]
    //   INITIAL_A = 200
    // }

    if ((await getChainId()) === CHAIN_ID.FANTOM || (await getChainId()) === CHAIN_ID.ARBITRUM) {
      TOKEN_ADDRESSES = [
        (await get("nUSD")).address,
        (await get("MIM")).address,
        (await get("USDC")).address,
        (await get("USDT")).address,
      ];
      TOKEN_DECIMALS = [18, 18, 6, 6];
    }

    const LP_TOKEN_NAME = "nUSD LP";
    const LP_TOKEN_SYMBOL = "nUSD-LP";
    const SWAP_FEE = 4e6; // 4bps
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
    await save("nUSDPoolV2", {
      abi: (await get("SwapFlashLoan")).abi,
      address: usdSwapAddress,
    });

    const lpTokenAddress = (await read("nUSDPoolV2", "swapStorage")).lpToken;
    log(`USD pool LP Token at ${lpTokenAddress}`);

    await save("nUSDPoolV2-LPToken", {
      abi: (await get("LPToken")).abi,
      address: lpTokenAddress,
    });

    const currentOwner = await read("nUSDPoolV2", "owner");

    if (currentOwner == deployer) {
      log(
        `transferring the ownership of "nUSDPoolV2" to the multisig: ${
          (await get("DevMultisig")).address
        }`
      );
      await execute(
        "nUSDPoolV2",
        { from: deployer, log: true },
        "transferOwnership",
        (
          await get("DevMultisig")
        ).address
      );
    } else if (currentOwner == (await get("DevMultisig")).address) {
      log(`"nUSDPoolV2" is already owned by the multisig: ${(await get("DevMultisig")).address}`);
    }
  }
};

export default func;
func.tags = ["nUSDPoolV2"];
func.dependencies = ["SwapUtils", "SwapDeployer", "SwapFlashLoan"];
