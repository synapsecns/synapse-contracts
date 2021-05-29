// scripts/create-box.js
const { ethers, upgrades } = require('hardhat')

async function main() {
  const ECDSAFactory = await ethers.getContractFactory('ECDSAFactory')
  const ecdsaFactory = await ECDSAFactory.deploy()
  await ecdsaFactory.deployed()
  console.log('ECDSAFactory deployed to:', ecdsaFactory.address)
}

main()
