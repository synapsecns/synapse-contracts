#!/usr/bin/env bash
# This script will deploy SynapseRouter and its auxilary contracts on the given chain.
# Deployment address on every chain will depend on the deployer address initial nonce.
# Existing deployments will be reused rather than overwritten.

# Usage: ./script/router/deploy-router.sh <chainName> <walletName> [<options...>]

# Temp fix until Foundry bytecode matches solc bytecode EXACTLY
./script/sh/solc.sh SynapseRouter
# Pass the full list of arguments to the run script
./script/run.sh ./script/router/DeployRouterV1.s.sol "$@"
