import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { includes } from "lodash"
import { CHAIN_ID } from "../utils/network"

const hre = require("hardhat");
const ethers = hre.ethers;


const { deployments, getNamedAccounts, getChainId } = hre
const { deploy, get, save, execute, log, catchUnknownSigner } = deployments

const BigNumber = ethers.BigNumber;

async function deployToken() {
  const { deployer } = await getNamedAccounts()

  // const receipt = await execute(
  //   "SynapseERC20Factory",
  //   { from: deployer, log: true },
  //   "deploy",
  //   (
  //     await get("SynapseERC20")
  //   ).address,
  //   "MOCK",
  //   "MOCK",
  //   "18",
  //   deployer,
  // )

  // const newTokenEvent = receipt?.events?.find(
  //   (e: any) => e["event"] == "SynapseERC20Created",
  // )
  // const tokenAddress = newTokenEvent["args"]["contractAddress"]
  // log(`deployed MOCK token at ${tokenAddress}`)


  // await save("MOCK", {
  //   abi: (await get("SynapseERC20")).abi, // Generic ERC20 ABI
  //   address: tokenAddress,
  // })

  const MOCK = await ethers.getContract("MOCK")

  await MOCK.grantRole("0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",
  (
    await get("SynapseBridge")
  ).address)


  // await MOCK.grantRole("0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6", deployer)

  // await MOCK.mint(deployer, BigNumber.from("1000000000000000000000"))
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
deployToken()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
