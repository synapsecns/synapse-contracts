// scripts/create-box.js
const { ethers, upgrades } = require('hardhat')

async function main() {
  const ECDSANodeManagement = await ethers.getContractFactory(
    'ECDSANodeManagement'
  )
  const ecdsaNodeManagement = await ECDSANodeManagement.deploy()
  await ecdsaNodeManagement.deployed()
  console.log('ECDSA deployed to:', ecdsaNodeManagement.address)
}

main()
