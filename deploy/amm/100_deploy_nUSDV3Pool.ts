import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CHAIN_ID } from "../../utils/network";
import { includes } from "lodash";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { execute, get, getOrNull, log, read, save } = deployments;
  const { deployer } = await getNamedAccounts();

  // Manually check if the pool is already deployed
  let nUSDPoolV3 = await getOrNull("nUSDPoolV3");
  if (
    nUSDPoolV3 ||
    includes([CHAIN_ID.MAINNET, CHAIN_ID.MOONBEAM, CHAIN_ID.DFK], await getChainId())
  ) {
    // log(`reusing "nUSDPoolV3" at ${nUSDPoolV3}`)
  } else {
    // Constructor arguments
    let TOKEN_ADDRESSES = [];
    let TOKEN_DECIMALS = [];
    let INITIAL_A = 800;
    if (
      (await getChainId()) === CHAIN_ID.POLYGON ||
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

    if ((await getChainId()) === CHAIN_ID.AVALANCHE) {
      TOKEN_ADDRESSES = [
        (await get("nUSD")).address,
        (await get("USDC")).address,
        (await get("USDT")).address,
      ];
      INITIAL_A = 600;
      TOKEN_DECIMALS = [18, 6, 6];
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
        (await get("USDC")).address,
        (await get("USDT")).address,
      ];
      TOKEN_DECIMALS = [18, 6, 6];
      INITIAL_A = 400;
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

    if ((await getChainId()) === CHAIN_ID.CRONOS) {
      TOKEN_ADDRESSES = [(await get("nUSD")).address, (await get("USDC")).address];
      TOKEN_DECIMALS = [18, 6];
      INITIAL_A = 800;
    }

    if ((await getChainId()) === CHAIN_ID.OPTIMISM) {
      TOKEN_ADDRESSES = [(await get("nUSD")).address, (await get("USDC")).address];
      TOKEN_DECIMALS = [18, 6];
      INITIAL_A = 400;
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
        (await get("USDC")).address,
        (await get("USDT")).address,
      ];
      TOKEN_DECIMALS = [18, 6, 6];
    }

    const LP_TOKEN_NAME = "nUSD LP";
    const LP_TOKEN_SYMBOL = "nUSD-LP";
    const SWAP_FEE = 1e6; // 4bps
    const ADMIN_FEE = 9900000000;

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
    await save("nUSDPoolV3", {
      abi: (await get("SwapFlashLoan")).abi,
      address: usdSwapAddress,
    });

    const lpTokenAddress = (await read("nUSDPoolV3", "swapStorage")).lpToken;
    log(`USD pool LP Token at ${lpTokenAddress}`);

    await save("nUSDPoolV3-LPToken", {
      abi: (await get("LPToken")).abi,
      address: lpTokenAddress,
    });

    const currentOwner = await read("nUSDPoolV3", "owner");

    if (currentOwner == deployer) {
      log(
        `transferring the ownership of "nUSDPoolV3" to the multisig: ${
          (await get("DevMultisig")).address
        }`
      );
      await execute(
        "nUSDPoolV3",
        { from: deployer, log: true },
        "transferOwnership",
        (
          await get("DevMultisig")
        ).address
      );
    } else if (currentOwner == (await get("DevMultisig")).address) {
      log(`"nUSDPoolV3" is already owned by the multisig: ${(await get("DevMultisig")).address}`);
    }
  }
};

export default func;
func.tags = ["nUSDPoolV3"];
func.dependencies = ["SwapUtils", "SwapDeployer", "SwapFlashLoan"];
