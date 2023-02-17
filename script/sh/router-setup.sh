#!/usr/bin/env bash
# This script will configure SynapseRouter and its auxilary contracts
# on all chains specified in "./script/configs/production-networks.txt".
# If the existing deployments were previouslt configured, only the neccesary updates will be performed.

# Check if configure transactions need to be broadcasted, or is this just a multi-chain simulation
case "$1" in
"-b" | "-B" | "--broadcast")
  echo "Configure tx WILL be broadcasted on all chains."
  confArgs="--broadcast --verify"
  ;;
"")
  echo "Configure tx WILL NOT be broadcasted on any chains."
  confArgs="--sig 'runDry()'"
  ;;
*)
  echo "Unknown paratemer: $1"
  exit 1
  ;;
esac

readarray -t arr <script/configs/production-networks.txt
echo "Will be configuring SynapseRouter on ${#arr[@]} chains"

# Check if config exists for all chains
for chain in ${arr[@]}; do
  configFile="script/configs/$chain/SynapseRouter.dc.json"
  if [ ! -e "$configFile" ]; then
    echo "Config doesn't exist for $chain"
    exit 1
  fi
done

# Configure on all chains one by one
for chain in ${arr[@]}; do
  echo "Configure contracts on $chain"
  bash -x -c "forge script -f $chain script/router/SetupRouter.s.sol $confArgs"
done
