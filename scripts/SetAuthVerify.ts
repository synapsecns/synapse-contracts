const hre = require("hardhat");

const ethers = hre.ethers;

const { deployments, getNamedAccounts, getChainId } = hre;
const { deploy, get } = deployments;
import { CHAIN_ID } from "../utils/network";

import { includes } from "lodash";

async function main() {
  const signers = await ethers.getSigners();
  const AuthVerifierFactory = await ethers.getContractFactory("AuthVerifier");
  const authVerifier = AuthVerifierFactory.attach((await get("AuthVerifier")).address);
  if (includes([CHAIN_ID.DFK_TESTNET, CHAIN_ID.DFK], await getChainId())) {
    await authVerifier
      .connect(signers[3])
      .setNodeGroup("0xe1dd28e1cb0d473fd819449bf3abfc3152582a66");
  } else {
    await authVerifier.setNodeGroup("0xe1dd28e1cb0d473fd819449bf3abfc3152582a66");
  }
  console.log("Auth verifier updated");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
