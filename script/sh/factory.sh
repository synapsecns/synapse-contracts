#!/usr/bin/env bash
# This script will deploy SynapseDeploFactory on all chains specified in "./script/configs/production-networks.txt".
# Deployment address on every chain will depend on the factory deployer address initial nonce.
# Existing deployments will not be overwritten.

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
echo "Will be deploying factory on ${#arr[@]} chains"

# Deploy on all chains one by one
for chain in ${arr[@]}; do
  echo "Deploying Factory on [$chain]"
  bash -x -c "forge script --silent -f $chain script/factory/DeployFactory.s.sol $deployArgs"
done
