import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-waffle'
import '@nomiclabs/hardhat-web3'
import '@nomiclabs/hardhat-etherscan'
import '@typechain/hardhat'
import 'hardhat-gas-reporter'
import 'solidity-coverage'
import 'hardhat-deploy'
import 'hardhat-spdx-license-identifier'

import { HardhatUserConfig } from 'hardhat/config'
import dotenv from 'dotenv'

dotenv.config()

let config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  networks: {
    coverage: {
      url: 'http://127.0.0.1:8555',
    },
    bsctestnet: {
      url: 'https://data-seed-prebsc-1-s1.binance.org:8545',
      gasPrice: 100 * 1000000000,
    },
    testnet: {
      url: 'https://eth-ropsten.alchemyapi.io/v2/tmEmzPXw-YAGzFPxNjcYACSGIY8stGs0',
      gasPrice: 1 * 1000000000,
    },
    mainnet: {
      url: process.env.ALCHEMY_API,
      gasPrice: 140 * 1000000000,
    },
  },
  paths: {
    artifacts: './build/artifacts',
    cache: './build/cache',
  },
  typechain: {
    outDir: './build/typechain/',
    target: 'ethers-v5',
  },
  solidity: {
    compilers: [
      {
        version: '0.6.12',
        settings: {
          optimizer: {
            enabled: true,
            runs: 10000,
          },
        },
      },
      {
        version: '0.8.2',
      },
      {
        version: '0.8.3',
      },
    ],
  },
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
      1: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
    },
    libraryDeployer: {
      default: 1, // use a different account for deploying libraries on the hardhat network
      1: 0, // use the same address as the main deployer on mainnet
    },
  },
  gasReporter: {
    currency: 'USD',
    gasPrice: 21,
  },
  mocha: {
    timeout: 200000,
  },
  spdxLicenseIdentifier: {
    overwrite: false,
    runOnCompile: true,
  },
}

if (process.env.ETHERSCAN_API) {
  config = { ...config, etherscan: { apiKey: process.env.ETHERSCAN_API } }
}

module.exports = config
