// scripts/create-box.js
const { ethers, upgrades } = require('hardhat')

async function main() {
  const BridgeDeposit = await ethers.getContractFactory('BridgeDeposit')
  const bridgeDeposit = await upgrades.deployProxy(BridgeDeposit, [])
  await bridgeDeposit.deployed()
  console.log('Box deployed to:', bridgeDeposit.address)
}

main()
