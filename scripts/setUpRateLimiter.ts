import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { includes } from "lodash"
import { CHAIN_ID } from "../utils/network"

const hre = require("hardhat");
const ethers = hre.ethers;


const { deployments, getNamedAccounts, getChainId } = hre
const { deploy, get, execute, catchUnknownSigner } = deployments

async function main() {
    const { deployer } = await getNamedAccounts()
  const BigNumber = ethers.BigNumber;
  if (includes([CHAIN_ID.GOERLI, CHAIN_ID.FUJI], await getChainId())) {
    const RateLimiter = await ethers.getContract("RateLimiter");
    const Bridge = await ethers.getContract("SynapseBridge");

    // await RateLimiter.grantRole("0x71840dc4906352362b0cdaf79870196c8e42acafade72d5d5a6d59291253ceb1", deployer);

    // await RateLimiter.grantRole("0xf7b34cf87af24ce01c1aff9f518b133989851466d994e0016fc14651fa02826c", deployer);

    // await RateLimiter.grantRole("0x71840dc4906352362b0cdaf79870196c8e42acafade72d5d5a6d59291253ceb1", "0x168d1e134C636f19f924c39f4ac56b73bA827358")

    // await RateLimiter.grantRole("0xf7b34cf87af24ce01c1aff9f518b133989851466d994e0016fc14651fa02826c", "0x168d1e134C636f19f924c39f4ac56b73bA827358")

    // await RateLimiter.grantRole("0x52ba824bfabc2bcfcdf7f0edbb486ebb05e1836c90e78047efeb949990f72e5f", (
    //     await get("SynapseBridge")
    //   ).address);
    
    //   await RateLimiter.setBridgeAddress((
    //     await get("SynapseBridge")
    //   ).address)


    // await Bridge.grantRole("0x71840dc4906352362b0cdaf79870196c8e42acafade72d5d5a6d59291253ceb1", deployer)
    // await Bridge.grantRole("0x71840dc4906352362b0cdaf79870196c8e42acafade72d5d5a6d59291253ceb1", "0x168d1e134C636f19f924c39f4ac56b73bA827358")

    // await Bridge.setRateLimiter((
    //     await get("RateLimiter")
    //   ).address)

      const block = await ethers.provider.getBlock("latest")
      await RateLimiter.setAllowance(((await (get("MOCK"))).address), BigNumber.from("10000000000000000000"), 60, Math.floor((block.timestamp) / 60))
  } 
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });