#!/usr/bin/env bash
# This script will save the deploy configuration for SynapseRouter and its auxilary contracts
# on all chains specified in "./script/configs/production-networks.txt".
# Existing deploy configurations will not be overwritten.

readarray -t arr <script/configs/production-networks.txt
echo "Will be saving config for SynapseRouter on ${#arr[@]} chains"

for chain in ${arr[@]}; do
  configFile="script/configs/$chain/SynapseRouter.dc.json"
  # Check if config already exists
  if [ -e "$configFile" ]; then
    echo "Config already exists on $chain"
  else
    echo "Saving config for $chain"
    # Create a directory with chain's deploy configs if it doesn't exist
    dirName="script/configs/$chain"
    if [ ! -d "$dirName" ]; then
      mkdir -p "$dirName"
    fi
    bash -x -c "forge script --silent -f $chain script/router/SaveRouterConfig.s.sol"
  fi
done
