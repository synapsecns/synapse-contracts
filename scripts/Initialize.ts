const hre = require("hardhat");

const ethers = hre.ethers;

const { deployments, getNamedAccounts, getChainId } = hre;
const { deploy, get } = deployments;
import { CHAIN_ID } from "../utils/network";

import { includes } from "lodash";

async function main() {
  const signers = await ethers.getSigners();
  const SynapseBridgeFactory = await ethers.getContractFactory("SynapseBridge");
  const synapseBridgeImplementation = SynapseBridgeFactory.attach(
    (await get("SynapseBridge_Implementation")).address
  );

  await synapseBridgeImplementation.initialize();
  console.log("initialized");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
