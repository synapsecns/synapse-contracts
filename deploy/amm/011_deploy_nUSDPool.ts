import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
  import { CHAIN_ID } from "../../utils/network"


const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { execute, get, getOrNull, log, read, save } = deployments
  const { deployer } = await getNamedAccounts()

  // Manually check if the pool is already deployed
  let nUSDPool = await getOrNull("nUSDPool")
  if (nUSDPool) {
    log(`reusing "nUSDPool" at ${nUSDPool.address}`)
  } else {
      // Constructor arguments
    let TOKEN_ADDRESSES = []
    let TOKEN_DECIMALS = []
    if (await getChainId() === CHAIN_ID.POLYGON || await getChainId() === CHAIN_ID.AVALANCHE || await getChainId() === CHAIN_ID.ARBITRUM || await getChainId() === CHAIN_ID.BSC || await getChainId() === CHAIN_ID.HARDHAT) {        
      TOKEN_ADDRESSES = [
        (await get("nUSD")).address,
        (await get("USDPool-LPToken")).address,
        ]
      TOKEN_DECIMALS = [18, 18]
    }

    const LP_TOKEN_NAME = "nUSD LP"
    const LP_TOKEN_SYMBOL = "nUSD-LP"

    const INITIAL_A = 2000
    const SWAP_FEE = 4e6 // 4bps
    const ADMIN_FEE = 6000000000


    const receipt = await execute(
      "MetaSwapDeployer",
      { from: deployer, log: true },
      "deploy",
      TOKEN_ADDRESSES,
      TOKEN_DECIMALS,
      LP_TOKEN_NAME,
      LP_TOKEN_SYMBOL,
      INITIAL_A,
      SWAP_FEE,
      ADMIN_FEE,
      (
        await get("LPToken")
      ).address,
      (
        await get("USDPool")
      ).address,
    )

    const newPoolEvent = receipt?.events?.find(
      (e: any) => e["event"] == "NewMetaSwapPool",
    )
    const nusdSwapAddress = newPoolEvent["args"]["metaSwapAddress"]
    const nusdSwapDepositAddress = newPoolEvent["args"]["metaSwapDepositAddress"]
    log(
      `deployed nUSD pool clone (targeting "nUSDPool") at ${nusdSwapAddress}`,
    )
    await save("nUSD-Deposit", {
      abi: (await get("MetaSwapDeposit")).abi,
      address: nusdSwapDepositAddress,
    })
    log(
      `deployed USD metapool deposit clone (targeting "nUSDPool") at ${nusdSwapDepositAddress}`,
    )
    await save("nUSDPool", {
      abi: (await get("MetaSwap")).abi,
      address: nusdSwapAddress,
    })

    const lpTokenAddress = (await read("nUSDPool", "swapStorage"))
      .lpToken
    log(`USD pool LP Token at ${lpTokenAddress}`)

    await save("nUSD-LPToken", {
      abi: (await get("USDC")).abi, // Generic ERC20 ABI
      address: lpTokenAddress,
    })
  }
}

export default func
func.tags = ["nUSDPool"]
func.dependencies = [
  "SwapUtils",
  "MetaSwapUtils",
  "SwapDeployer",
  "SwapFlashLoan",
  "MetaSwapDeposit",
  "MetaSwap",
  "MetaSwapDeployer",
  "USDPool",
  "USDPoolTokens",
]
