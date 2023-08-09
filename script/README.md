# Old scripts deprecation notice

Some of the scripts (and files used by them) in this folder are deprecated and will be moved/reworked in the future. These are:

- `networks-eip-1559` and `networks-legacy` files.
- Script templates from `utils` folder, and scripts using them.
- Scripts from `sh` folder.

# Usage of the test script templates.

In this repo we have two types of Foundry test files (`*.t.sol`)

- Base tests: these are named `contract *Test`.
- Fork tests: these are named `contract *TestFork`.

## Base tests

Base tests are unit or integration tests that either don't require any live state, or that could use the simulated state.
They do not require any special setup and could be launched using:

```bash
# Runs all base tests
$ ./script/foundry-base.sh
# Runs base tests for contracts having Bus in their name
$ ./script/foundry-base.sh Bus
```

Base tests are a part of the CI workflow called `foundry-base`.

## Fork tests

Fork tests are written for contract upgrades and new integrations. These should use the RPC URL from the `.env` file (check `.env.example` for the env variable name).

Fork tests could be launched using a separate script:

```bash
# Runs all fork tests
$ ./script/foundry-fork.sh
# Runs fork tests for contracts having Klaytn in their name
$ ./script/foundry-fork.sh Klaytn
```

Fork tests are not a part of the CI workflow. Instead, they are supposed to be run before the deployment goes live.

# Usage of the deployment script templates.

## Setting up the environment variables.

1. Copy the `env.example` file to `.env`.
2. Replace `PasteYourOwnKeyPlease` with your own etherscan-clone API key for the chains you want to deploy verified contracts.
3. Feel free to replace some of the RPC urls, if the default ones are not working for you.
4. Define wallets as per the example in the file.
   > Available options:
   >
   > - Keystore files, currently foundry only supports keystore files saved by `cast wallet new <path>` command, keystores exported from other sources will not work.
   > - Ledger and Trezor wallets.
   > - Interactive prompt for entering the private key.
5. Make sure you have enough ETH in the wallets to pay for the gas fees.

## Available chains for deployment.

Every chain has its own name, which is used in <a href="../.env.example">.env</a>, <a href="../foundry.toml">foundry.toml</a>, <a href="../deployments">deployments</a> and <a href="./configs">script/configs</a>. Therefore, it is important to use the same name for the chain everywhere.

> - `.env.example` is linked here instead of `.env` because the latter is ignored by git and does not belong to the public repo.
> - The list of chains names could be found in `foundry.toml` file.

### Chain-specific script options.

Some of the chains require additional options to be passed to `forge script`. These are defined in <a href="./networks.json">script/networks.json</a> file. The most obvious example is `--legacy` flag that needs to be passed for the chains that do not support eip-1559.

### Adding a new chain.

`xyz` is used as an example chain name.

- Create `deployments/xyz/.chainId` file and put a single line with the chain id in it.
- Create `.deployments/xyz` folder as well.
- Modify following files. Enforce alphabetical order of the chains in every file.

#### 1. Add environment variables for the new chain.

Modify <a href="../.env.example">.env.example</a> by adding the following lines (modify `.env` accordingly):

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

#### 2. Add foundry config for the new chain.

Modify <a href="../foundry.toml">foundry.toml</a> by adding the following lines:

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

#### 3. Add network-specific forge options for the new chain.

Modify <a href="./networks.json">networks.json</a> by adding the following lines:

```json
{
  "xyz": "list options here if needed"
}
```

## Setting up the config files for the contracts.

Config files are stored in <a href="./configs">script/configs</a> folder.

### Chain-specific config files.

Some of the contracts require parameters that are different for each chain. These are saved as `script/configs/chainName/contractName.dc.json` (dc stands for deployment config).

> Example: <a href="./configs/bsc/SynapseRouter.dc.json">SynapseRouter.dc.json</a> is used for `SynapseRouter` contract on BSC.

### Global config files.

Some of the contracts have parameters that are the same for all chains. These are saved as `script/configs/globalName.json`.

> Example: <a href="./configs/SynapseCCTP.chains.json">SynapseCCTP.chains.json</a> is used for `SynapseCCTP` contract on all chains.

## Writing a deployment script.

1. Use <a href="./templates/BasicSynapse.s.sol">BasicSynapse.s.sol</a> as base for your deployment script.
   > Check out the available functions in <a href="./templates/BasicUtils.sol">BasicUtils.sol</a> and <a href="./templates/StringUtils.sol">StringUtils.sol</a> as well.
2. The templates are using `pragma solidity >=0.6.12;`. Take advantage of that by having the same compiler version in your deployment script and the deployed contracts.
3. Avoid hardcoding the parameters in the deployment script. Instead use either the [chain-specific config files](#chain-specific-config-files) or the [global config files](#global-config-files).
   > JSON configs could be loaded using `getDeployConfig` and `getGlobalDeployConfig` functions from <a href="./templates/BasicUtils.sol">BasicUtils.sol</a>.
4. Use `deployAndSave` or `deployAndSaveAs` for deploying the contracts and saving their deployment artifacts.
   > - These functions require providing a callback function for deployment, check out the corresponding docs.
   > - These functions will save the deployment artifacts in `.deployments` folder, which is ignored by git.
   > - Note: these functions are no-ops, if the contract artifact for the active chain is already present in <a href="../deployments">deployments</a> folder.

### Existing examples of deployment scripts

- <a href="./router/quoter/DeployDefaultPoolCalc.s.sol">DeployDefaultPoolCalc.s.sol</a>: create2 deployment of DefaultPoolCalc.
- <a href="./router/quoter/DeployDefaultPoolCalcExample.s.sol">DeployDefaultPoolCalcExample.s.sol</a>: usual deployment of DefaultPoolCalc (for demonstration only)</a>.

## Deploying contracts.

1. Use <a href="./run.sh">script/run.sh</a> to run your deployment script. Check `run.sh` code for the available options.
   > - You can do `script/run.sh path/to/script.s.sol chain wallet` first to simulate the deployment and see the gas fees. This will also print the wallet balance and nonce.
   > - Follow that with added `--broadcast --verify` to deploy the contracts and **attempt** to verify them.
2. Use <a href="./save-deployment.sh">script/save-deployment.sh</a> to move the artifacts for the deployed contracts from `.deployments` to `deployments`. Check `save-deployment.sh` code for the available options.
   > Script will check that the address from the artifact has code deployed at it.
   > This is useful when running a simulation script, or when broadcasting of the deployment script fails, but deployments are saved to `.deployments` anyway (which happens **before** the transactions from the script are broadcasted).
3. Use <a href="./verify-contract.sh">script/verify-contract.sh</a> to verify the contracts that were deployed in step 1. Check `verify-contract.sh` code for the available options.
