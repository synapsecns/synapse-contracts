import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { CHAIN_ID } from "../../utils/network"
import {includes} from "lodash";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { execute, get, getOrNull, log, read, save } = deployments
  const { deployer } = await getNamedAccounts()

  // Manually check if the pool is already deployed
  let BridgedAVAXPool = await getOrNull("BridgedAVAXPool")
  if (BridgedAVAXPool) {
    log(`reusing "BridgedAVAXPool" at ${BridgedAVAXPool.address}`)
  } else if ((includes([CHAIN_ID.HARMONY], await getChainId()))) {
    // Constructor arguments
    const TOKEN_ADDRESSES = [
      (await get("AVAX")).address,
      (await get("multiAVAX")).address
    ]
    const TOKEN_DECIMALS = [18, 18]
    const LP_TOKEN_NAME = "AVAX-LP"
    const LP_TOKEN_SYMBOL = "AVAX-LP"
    const INITIAL_A = 800
    const SWAP_FEE = 4e6 // 4bps
    const ADMIN_FEE = 9000000000

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
      ).address,
    )

    const newPoolEvent = receipt?.events?.find(
      (e: any) => e["event"] == "NewSwapPool",
    )
    const usdSwapAddress = newPoolEvent["args"]["swapAddress"]
    log(
      `deployed ETH pool clone (targeting "SwapFlashLoan") at ${usdSwapAddress}`,
    )
    await save("BridgedAVAXPool", {
      abi: (await get("SwapFlashLoan")).abi,
      address: usdSwapAddress,
    })

    const lpTokenAddress = (await read("BridgedAVAXPool", "swapStorage")).lpToken
    log(`ETH pool LP Token at ${lpTokenAddress}`)

    await save("BridgedAVAXPoolLPToken", {
      abi: (await get("DAI")).abi, // Generic ERC20 ABI
      address: lpTokenAddress,
    })

    const currentOwner = await read("BridgedAVAXPool", "owner")

    if (currentOwner == deployer) {
      log(
        `transferring the ownership of "BridgedAVAXPool" to the multisig: ${(await get("DevMultisig")).address}`,
      )
      await execute(
        "BridgedAVAXPool",
        { from: deployer, log: true },
        "transferOwnership",
        (await get("DevMultisig")).address,
      )
    } else if (currentOwner == (await get("DevMultisig")).address){
      log(
        `"BridgedAVAXPool" is already owned by the multisig: ${(await get("DevMultisig")).address}`,
      )
    }
  }
}
export default func
func.tags = ["BridgedAVAXPool"]
func.dependencies = [
  "SwapUtils",
  "SwapDeployer",
  "SwapFlashLoan",
  "USDPoolTokens",
]
