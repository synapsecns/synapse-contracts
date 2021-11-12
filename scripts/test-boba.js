// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

const ethers = hre.ethers;

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const SynapseBridgeFactory = await hre.ethers.getContractFactory("SynapseBridge");

  await network.provider.request({
    method: "hardhat_reset",
    params: [
      {
        forking: {
          jsonRpcUrl: "https://mainnet.boba.network",
          blockNumber: 18856,
        },
      },
    ],
  });

  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: ["0x230a1ac45690b9ae1176389434610b9526d2f21b"],
  });
  const nodes = await ethers.getSigner("0x230a1ac45690b9ae1176389434610b9526d2f21b")

//   await network.provider.send("hardhat_setBalance", [
//     "0xd7aDA77aa0f82E6B3CF5bF9208b0E5E1826CD79C",
//     "0x9900000000000000",
//   ]);
  


  const bridge = await SynapseBridgeFactory.attach("0x432036208d2717394d2614d6697c46DF3Ed69540")

  console.log(await ethers.provider.getBalance("0xba370a6aad78b86af72e0959e0feab2cba4b2c5d"))
  const res = await bridge.connect(nodes).mintAndSwap("0xba370a6aad78b86af72e0959e0feab2cba4b2c5d","0x96419929d7949d6a801a6909c145c8eef6a40431", "5990085943257749", "5000000000000000", "0xab1eb0b9a0124d89445a547366c9ed61a5180e43", "0", "1", "0", "1636838708", "0xd55dc5175bcd7d1174c51fa8272cdac274f3a66da9d28b0b4098a760a1d1a768")
  console.log(res)
  console.log(await ethers.provider.getBalance("0xba370a6aad78b86af72e0959e0feab2cba4b2c5d"))
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });