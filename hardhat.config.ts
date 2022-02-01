import "@tenderly/hardhat-tenderly"
import "@nomiclabs/hardhat-ethers"
import "@nomiclabs/hardhat-waffle"
import "@nomiclabs/hardhat-web3"
import "@nomiclabs/hardhat-etherscan"
import "@typechain/hardhat"
import "hardhat-gas-reporter"
import "solidity-coverage"
import "hardhat-deploy"
import "hardhat-spdx-license-identifier"
import "hardhat-interface-generator";


import { HardhatUserConfig } from "hardhat/config"
import dotenv from "dotenv"

dotenv.config()

let config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  networks: {
    coverage: {
      url: "http://127.0.0.1:8555",
    },
    arbitrum: {
      url: "https://arb1.arbitrum.io/rpc",
      gasPrice: 2 * 1000000000,
      // gas: 100000000
    },
    mumbai: {
      url: "https://polygon-mumbai.infura.io/v3/ce8ef4b53e0c45c899ef862be05afd55",
      gasPrice: 2 * 1000000000,
    },
    bsctestnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      gasPrice: 10 * 1000000000,
    },
    testnet: {
      url: "https://eth-ropsten.alchemyapi.io/v2/tmEmzPXw-YAGzFPxNjcYACSGIY8stGs0",
      gasPrice: 2 * 1000000000,
    },
    fantom: {
      url: "https://rpc.ftm.tools/",
    },
    polygonprodtest: {
      url: "https://polygon-mainnet.infura.io/v3/ce8ef4b53e0c45c899ef862be05afd55",
      gasPrice: 6 * 1000000000,
    },
    polygon: {
      url: "https://polygon-mainnet.infura.io/v3/ce8ef4b53e0c45c899ef862be05afd55",
      // gasPrice: 40 * 1000000000,
    },
    bsc: {
      url: "https://bsc-dataseed1.defibit.io",
      gasPrice: 6 * 1000000000,
    },
    avalanche: {
      url: "https://api.avax.network/ext/bc/C/rpc",
      // gasPrice: 750 * 1000000000,
    },
    harmony: {
      url: "https://harmony-0-rpc.gateway.pokt.network/",
      gasPrice: 6 * 1000000000,
    },
    boba: {
      url: "https://mainnet.boba.network",
      gas: 10000000,
      gasPrice: 20 * 1000000000,
    },
    moonriver: {
      url: "https://rpc.moonriver.moonbeam.network",
      gasPrice: 10 * 1000000000
    },
    aurora: {
      url: "https://mainnet.aurora.dev",
      gasPrice: 0
    },
    mainnet: {
      url: process.env.ALCHEMY_API,
    },
    optimism: {
      url: "https://mainnet.optimism.io",
      gas: 10000000,
      // gasPrice: 1 * 1000000000,
    },
    tenderly_prepmainnet: {
      url: process.env.ALCHEMY_API,
    },
    tenderly_mainnet: {
      url: "https://rpc.tenderly.co/fork/8a1fb06a-1926-4b7f-9f01-35d8dcb3d3a2"
    },
    tenderly_avalanche: {
      url: "https://rpc.tenderly.co/fork/58adc3b9-17eb-4c96-aa40-8eb52717dcad"
    },
    tenderly_arbitrum: {
      url: "https://rpc.tenderly.co/fork/f817917b-2e58-49d0-bac6-c2f04f8b6442"
    },
    tenderly_prepavalanche: {
      url: "https://api.avax.network/ext/bc/C/rpc",
    },
    tenderly_preparbi: {
      url: "https://arb1.arbitrum.io/rpc",
    }
  },
  paths: {
    artifacts: "./build/artifacts",
    cache: "./build/cache",
  },
  typechain: {
    outDir: "./build/typechain/",
    target: "ethers-v5",
  },
  solidity: {
    compilers: [
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 10000,
          },
        },
      },
      {
        version: "0.8.11",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.4.24",
      },
    ],
  },
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
      1: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
      42161: 0,
    },
    libraryDeployer: {
      default: 0, // use a different account for deploying libraries on the hardhat network
      1: 0, // use the same address as the main deployer on mainnet,
      250: 0,
    },
  },
  gasReporter: {
    currency: "USD",
    gasPrice: 21,
  },
  mocha: {
    timeout: 200000,
  },
  spdxLicenseIdentifier: {
    overwrite: false,
    runOnCompile: true,
  }
}

if (process.env.ETHERSCAN_API) {
  config = { ...config, etherscan: { apiKey: process.env.ETHERSCAN_API } }
}

if (process.env.PRIVATE_KEYS) {
  let PROD_NETWORKS = [
    "arbitrum",
    "bsc",
    "polygon",
    "avalanche",
    "mainnet",
    "fantom",
    "harmony",
    "boba",
    "moonriver",
    "optimism",
    "aurora",
    "tenderly_prepmainnet",
    "tenderly_prepavalanche",
    "tenderly_preparbi"
  ]
  Object.keys(config.networks).forEach((network) => {
    if (PROD_NETWORKS.includes(network)) {
      config.networks = {
        ...config.networks,
        [network]: {
          ...config.networks?.[network],
          accounts: JSON.parse(process.env.PRIVATE_KEYS),
        },
      }
    }
  })
}

module.exports = config
