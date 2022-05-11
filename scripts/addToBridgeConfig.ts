import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { includes } from "lodash"
import { CHAIN_ID } from "../utils/network"
import { BridgeConfigV3 } from "../build/typechain/BridgeConfigV3"


const hre = require("hardhat");
const ethers = hre.ethers;


const { deployments, getNamedAccounts, getChainId } = hre
const { deploy, get, execute, catchUnknownSigner } = deployments

async function main() {
    const { deployer } = await getNamedAccounts()

  if (includes([CHAIN_ID.GOERLI, CHAIN_ID.FUJI], await getChainId())) {
    const BridgeConfig: BridgeConfigV3 = await ethers.getContract("BridgeConfigV3");
    console.log(BridgeConfig.address);
    // const tx = await BridgeConfig["setTokenConfig(string,uint256,address,uint8,uint256,uint256,uint256,uint256,uint256,bool,bool)"](
    //   "MOCK",
    //   43113,
    //   "0xbaFc462d00993fFCD3417aBbC2eb15a342123FDA",
    //   18,
    //   0,
    //   1,
    //   10000000,
    //   0,
    //   1,
    //   false,
    //   false
    // )

    // console.log(tx);
    
    // await BridgeConfig.setMaxGasPrice(43113, "100000000000")
    // await BridgeConfig.setMaxGasPrice(5, "100000000000")

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