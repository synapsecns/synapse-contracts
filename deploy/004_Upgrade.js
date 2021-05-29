// scripts/upgrade-box.js
const { ethers, upgrades } = require('hardhat')

async function main() {
  const BridgeDeposit = await ethers.getContractFactory('BridgeDeposit')
  const bridgeDeposit = await upgrades.upgradeProxy(
    '0x3E8A94915D70490A24726ee485C874A89dd949DF',
    BridgeDeposit
  )
  console.log('Box upgraded')
}

main()
