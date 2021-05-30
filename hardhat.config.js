require('@nomiclabs/hardhat-ethers')
require('@nomiclabs/hardhat-waffle')
require('@nomiclabs/hardhat-web3')
require('@nomiclabs/hardhat-etherscan')
require('hardhat-gas-reporter')
require('solidity-coverage')
require('hardhat-deploy')
require('hardhat-spdx-license-identifier')
require('@openzeppelin/hardhat-upgrades')

const dotenv = require('dotenv')

dotenv.config()

let config = {
  defaultNetwork: 'hardhat',
  networks: {
    coverage: {
      url: 'http://127.0.0.1:8555',
    },
    testnet: {
      url: 'https://eth-ropsten.alchemyapi.io/v2/tmEmzPXw-YAGzFPxNjcYACSGIY8stGs0',
      gasPrice: 1 * 1000000000,
      account: {
        mnemonic:
          'more foil hint dinosaur letter mesh ritual public hover decrease simple drum',
      },
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
