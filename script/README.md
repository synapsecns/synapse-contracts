# Usage of the script templates.

## Setting up the environment variables.

1. Copy the `env.example` file to `.env`.
2. Replace `PasteYourOwnKeyPlease` with your own etherscan-clone API key for the chains you want to deploy verified contracts.
3. Feel free to replace some of the RPC urls, if the default ones are not working for you.
4. Define wallets as per the example in the file.
5. Make sure you have enough ETH in the wallets to pay for the gas fees.

## Available chains for deployment.

Every chain has its own name, which is used in `.env`, `foundry.toml`, `deployments` and `script/configs`. Therefore, it is important to use the same name for the chain everywhere. The list of chains could be found in `foundry.toml` file.

### Chain-specific script options.

Some of the chains require additional options to be passed to `forge script`. These are defined in `config/networks.json` file. The most obvious example is `--legacy` flag that needs to be passed for the chains that do not support eip-1559.

### Adding a new chain.

Create `deployments/xyz/.chainId` file and put a single line with the chain id in it. Create `.deployments/xyz` folder as well.

Following lines need to be added, replacing `xyz` with the actual name of the chain. Enforce alphabetical order of the chains in every file.

#### `.env` and `.env.example`

```env
# MAINNET CHAINS
# Xyz
XYZ_API=<insert RPC URL here>
# For chains with Etherscan-clone block explorer.
XYZ_ETHERSCAN_URL=<insert Etherscan URL here>
XYZ_ETHERSCAN_KEY=<insert Etherscan API key in .env, placeholder in .env.example>
# For chains with Blockscout-clone block explorer.
XYZ_BLOCKSCOUT_URL=<insert Blockscout URL here>
```

#### `foundry.toml`

```toml
[rpc_endpoints]
xyz = "${XYZ_API}"

[etherscan]
# For chains with Etherscan-clone block explorer.
xyz = { key = "${XYZ_ETHERSCAN_KEY}", url = "${XYZ_ETHERSCAN_URL}" }

# For chains with Blockscout-clone block explorer.
xyz = { key = "", url = "${XYZ_BLOCKSCOUT_URL}" }

# For chains with neither add a comment like  ones of these.
# XYZ is using Sourcify for verification
# XYZ doesn't have an endpoint for verification, and Sourcify does not support Harmony
# XYZ doesn't have an endpoint for verification, and doesn't support Sourcify yet
```

#### `config/networks.json`

```json
{
  "xyz": "list options here if needed"
}
```

## Setting up the config files for the contracts.

Config files are stored in `script/configs` folder.

### Chain-specific config files.

Some of the contracts require parameters that are different for each chain. These are saved as `script/configs/chainName/contractName.dc.json` (dc stands for deployment config).

> Example: `script/configs/bsc/SynapseRouter.dc.json`.

### Global config files.

Some of the contracts have parameters that are the same for all chains. These are saved as `script/configs/globalName.json`.

> Example: `script/configs/SynapseCCTP.chains.json`.

## Writing a deployment script.

1. Use `script/templates/BasicSynapse.s.sol` as base for your deployment script.
   > Check out the available functions in `BasicUtils.sol` and `StringUtils.sol` as well.
2. The templates are using `pragma solidity >=0.6.12;`. Take advantage of that by having the same compiler version in your deployment script and the deployed contracts.
3. Avoid hardcoding the parameters in the deployment script. Instead use either the [chain-specific config files](#chain-specific-config-files) or the [global config files](#global-config-files).
   > JSON configs could be loaded using `getDeployConfig` and `getGlobalDeployConfig` functions from `BasicUtils.sol`.
4. Use `deployAndSave` or `deployAndSaveAs` for deploying the contracts and saving their deployment artifacts.
   > - These functions require providing a callback function for deployment, check out the corresponding docs.
   > - These functions will save the deployment artifacts in `.deployments` folder, which is ignored by git.
   > - Note: these functions are no-ops, if the contract artifact is already present in `deployments`.

## Deploying contracts.

1. Use `script/run.sh` to run your deployment script. Check `run.sh` code for the available options.
   > - You can do `script/run.sh path/to/script.s.sol chain wallet` first to simulate the deployment and see the gas fees. This will also print the wallet balance and nonce.
   > - Follow that with added `--broadcast --verify` to deploy the contracts and **attempt** to verify them.
2. Use `script/save-deployment.sh` to move the artifacts for the deployed contracts from `.deployments` to `deployments`. Check `save-deployment.sh` code for the available options.
   > Script will check that the address from the artifact has code deployed at it.
   > This is useful when running a simulation script, or when broadcasting of the deployment script fails, but deployments are saved to `.deployments` anyway (which happens **before** the transactions from the script are broadcasted).
3. Use `script/verify-contract.sh` to verify contracts that were not verified in step 1. Check `verify-contract.sh` code for the available options.
