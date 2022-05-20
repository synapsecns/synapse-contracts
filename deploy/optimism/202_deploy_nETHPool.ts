import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CHAIN_ID } from "../../utils/network";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy, execute, get, getOrNull, log, read, save } = deployments;
  const { deployer } = await getNamedAccounts();

  // // Manually check if the pool is already deployed
  // let ETHPool = await getOrNull("ETHPool")
  // if (ETHPool) {
  //   log(`reusing "ETHPool" at ${ETHPool.address}`)
  // } else if (
  //   (await getChainId()) != CHAIN_ID.OPTIMISM &&
  //   (await getChainId()) != CHAIN_ID.HARDHAT
  // ) {
  //   log(`Not Optimism or Hardhat`)
  // } else {
  //   // Constructor arguments
  //   const TOKEN_ADDRESSES = [
  //     (await get("nETH")).address,
  //     (await get("WETH")).address
  //   ]
  //   const TOKEN_DECIMALS = [18, 18]
  //   const LP_TOKEN_NAME = "nETH-LP"
  //   const LP_TOKEN_SYMBOL = "nETH-LP"
  //   const INITIAL_A = 100
  //   const SWAP_FEE = 4e6 // 4bps
  //   const ADMIN_FEE = 6000000000

  //   await deploy('ETHPool', {
  //       contract: 'SwapFlashLoan',
  //       from: deployer,
  //       log: true,
  //       libraries: {
  //           SwapUtils: (await get("SwapUtils")).address,
  //           AmplificationUtils: (await get("AmplificationUtils")).address,
  //         },
  //       skipIfAlreadyDeployed: true,
  //     })

  //   const receipt = await execute(
  //     "ETHPool",
  //     { from: deployer, log: true },
  //     "initialize",
  //     TOKEN_ADDRESSES,
  //     TOKEN_DECIMALS,
  //     LP_TOKEN_NAME,
  //     LP_TOKEN_SYMBOL,
  //     INITIAL_A,
  //     SWAP_FEE,
  //     ADMIN_FEE,
  //     (
  //       await get("LPToken")
  //     ).address,
  //   )

  //   const lpTokenAddress = (await read("ETHPool", "swapStorage")).lpToken
  //   log(`ETH pool LP Token at ${lpTokenAddress}`)

  //   await save("ETHPoolLPToken", {
  //     abi: (await get("DAI")).abi, // Generic ERC20 ABI
  //     address: lpTokenAddress,
  //   })
  // }
};
export default func;
func.tags = ["ETHPool"];
func.dependencies = ["SwapUtils", "SwapDeployer", "SwapFlashLoan"];
