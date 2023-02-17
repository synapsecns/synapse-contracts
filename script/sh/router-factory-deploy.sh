#!/usr/bin/env bash
# This script will deploy SynapseRouter and its auxilary contracts
# on all chains specified in "./script/configs/production-networks.txt".
# Synapse Deploy Factory will be used, meaning the deployment address on every chain
# will depend on the deployer address, and the provided salts for every deployment.
# Deployer nonce can be arbitrary on every chain.
# Existing deployments will be reused rather than overwritten.

# Check if deploy transactions need to be broadcasted, or is this just a multi-chain simulation
case "$1" in
"-b" | "-B" | "--broadcast")
  echo "Deploy tx WILL be broadcasted on all chains."
  deployArgs="--broadcast --verify"
  ;;
"")
  echo "Deploy tx WILL NOT be broadcasted on any chains."
  deployArgs="--sig 'runDry()'"
  ;;
*)
  echo "Unknown paratemer: $1"
  exit 1
  ;;
esac

readarray -t arr <script/configs/production-networks.txt
echo "Will be deploying SynapseRouter using SynapseFactory on ${#arr[@]} chains"

# Check if config exists for all chains
for chain in ${arr[@]}; do
  configFile="script/configs/$chain/SynapseRouter.dc.json"
  if [ ! -e "$configFile" ]; then
    echo "Config doesn't exist for $chain"
    exit 1
  fi
done

# Deploy on all chains one by one
for chain in ${arr[@]}; do
  echo "Deploying on $chain"
  bash -x -c "forge script -f $chain script/router/DeployFactoryRouter.s.sol $deployArgs"
done
