# Using scripts to run Foundry tests

In this repo we have two types of Foundry test files (`*.t.sol`)

- Base tests: these are named `contract *Test`.
- Fork tests: these are named `contract *TestFork`.

## Base tests

Base tests are unit or integration tests that either don't require any live state, or that could use the simulated state.
They do not require any special setup and could be launched using:

```bash
# Runs all base tests
$ ./scripts/foundry-base.sh
# Runs base tests for contracts having Bus in their name
$ ./scripts/foundry-base.sh Bus
```

Base tests are a part of the CI workflow called `foundry-base`.

## Fork tests

Fork tests are written for contract upgrades and new integrations. These require providing an RPC URL in the `.env` file (check the test contract to get the env variable name).

```
KLAY_API=https://klaytn.blockpi.network/v1/rpc/public
```

Fork tests could be launched using a separate script:

```bash
# Runs all fork tests
$ ./scripts/foundry-fork.sh
# Runs fork tests for contracts having Klaytn in their name
$ ./scripts/foundry-fork.sh Klaytn
```

Fork tests are not a part of the CI workflow. Instead, they are supposed to be run before the deployment goes live.
