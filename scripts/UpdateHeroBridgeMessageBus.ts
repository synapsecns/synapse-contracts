const hre = require("hardhat");

const ethers = hre.ethers;

const { deployments, getNamedAccounts, getChainId } = hre;
const { deploy, get } = deployments;
import { CHAIN_ID } from "../utils/network";

import { includes } from "lodash";

async function main() {
  const signers = await ethers.getSigners();
  const HeroBridgeFactory = await ethers.getContractFactory("HeroBridgeUpgradeable");
  const heroBridge = HeroBridgeFactory.attach((await get("HeroBridgeUpgradeable")).address);
  if (includes([CHAIN_ID.DFK_TESTNET, CHAIN_ID.DFK], await getChainId())) {
    await heroBridge.connect(signers[3]).setMessageBus((await get("MessageBus")).address);
  } else {
    await heroBridge.setMessageBus((await get("MessageBus")).address);
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
