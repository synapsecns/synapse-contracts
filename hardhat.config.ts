import "@tenderly/hardhat-tenderly";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-web3";
import "@nomiclabs/hardhat-etherscan";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "hardhat-deploy";
import "hardhat-spdx-license-identifier";
import "hardhat-interface-generator";
import "@primitivefi/hardhat-dodoc";
import "hardhat-deploy-ethers";

import { HardhatUserConfig } from "hardhat/config";
import dotenv from "dotenv";

dotenv.config();

let config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 31337,
    },
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
    dogechain: {
      url: "https://rpc-us.dogechain.dog/",
    },
    polygon: {
      url: "https://polygon-rpc.com",
      gasPrice: 400 * 1000000000,
      gas: 1000000,
    },
    bsc: {
      url: "https://bsc-dataseed1.defibit.io",
      gasPrice: 6 * 1000000000,
    },
    avalanche: {
      url: "https://api.avax.network/ext/bc/C/rpc",
      // gasPrice: 200 * 1000000000,
    },
    harmony: {
      url: "https://a.api.s0.t.hmny.io/",
    },
    harmony_testnet: {
      url: "https://api.s0.b.hmny.io",
    },
    boba: {
      url: "https://mainnet.boba.network",
    },
    moonriver: {
      url: "https://rpc.moonriver.moonbeam.network",
      gasPrice: 10 * 1000000000,
    },
    moonbeam: {
      url: "https://rpc.api.moonbeam.network",
    },
    aurora: {
      url: "https://mainnet.aurora.dev",
    },
    metis: {
      url: "https://andromeda.metis.io/?owner=1088",
    },
    dfk: {
      url: "https://subnets.avax.network/defi-kingdoms/dfk-chain/rpc",
      gas: 1000000,
    },
    dfk_testnet: {
      url: "https://subnets.avax.network/defi-kingdoms/dfk-chain-testnet/rpc	",
    },
    mainnet: {
      url: process.env.ALCHEMY_API || "https://main-light.eth.linkpool.io/",
    },
    fuji: {
      url: "https://api.avax-test.network/ext/bc/C/rpc",
    },
    goerli: {
      url: "https://rpc.goerli.mudit.blog/",
    },
    optimism: {
      url: "https://mainnet.optimism.io",
      gas: 10000000,
      // gasPrice: 1 * 1000000000,
    },
    cronos: {
      url: "https://evm-cronos.crypto.org",
      gasPrice: 5000 * 1000000000,
    },
    klatyn: {
      url: "https://cypress.chain.thebifrost.io/",
      gasPrice: 250 * 1000000000,
    },
    klaytn_testnet: {
      url: "https://api.baobab.klaytn.net:8651",
      gasPrice: 250 * 1000000000,
    },
    canto: {
      url: "https://canto.slingshot.finance",
    },
  },
  paths: {
    artifacts: "./build/artifacts",
    cache: "./build/cache",
  },
  typechain: {
    outDir: "./build/typechain/",
    target: "ethers-v5",
  },
  dodoc: {
    // skip doc generation on ci
    runOnCompile: process.env.CI == "",
    debugMode: false,
    // pre solidity 5 breaks docgen
    exclude: ["MultisigWallet", "WETH9"],
    // More options...
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
        version: "0.8.0",
      },
      {
        version: "0.8.2",
      },
      {
        version: "0.8.3",
      },
      {
        version: "0.4.25",
      },
      {
        version: "0.4.24",
      },
      {
        version: "0.8.13",
        settings: {
          optimizer: {
            enabled: true,
            runs: 5000000, // see: https://github.com/ethereum/solidity/issues/5394#issue-379536332
          },
        },
      },
      {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 5000000, // see: https://github.com/ethereum/solidity/issues/5394#issue-379536332
          },
        },
      },
    ],
  },
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
      1: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
      42161: 0,
      53935: 3,
      335: 3,
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
    require: ["dd-trace/ci/init"],
  },
  spdxLicenseIdentifier: {
    overwrite: false,
    runOnCompile: true,
  },
};

if (process.env.ETHERSCAN_API) {
  config = { ...config, etherscan: { apiKey: process.env.ETHERSCAN_API } };
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
    "moonbeam",
    "optimism",
    "aurora",
    "cronos",
    "metis",
    "dfk",
    "dfk_testnet",
    "harmony_testnet",
    "fuji",
    "goerli",
    "klatyn",
    "klaytn_testnet",
    "canto",
    "dogechain",
  ];
  Object.keys(config.networks).forEach((network) => {
    if (PROD_NETWORKS.includes(network)) {
      config.networks = {
        ...config.networks,
        [network]: {
          ...config.networks?.[network],
          accounts: JSON.parse(process.env.PRIVATE_KEYS),
        },
      };
    }
  });
}

module.exports = config;
