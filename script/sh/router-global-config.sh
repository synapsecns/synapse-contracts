#!/usr/bin/env bash
# This script will save the deploy configuration for SynapseRouter and its auxilary contracts
# on all chains specified in
# - "./script/configs/networks-eip-1559"
# - "./script/configs/networks-legacy"
# Existing deploy configurations will not be overwritten unless expicitly instructed.

# Usage: ./script/sh/router-global-config.sh [--overwrite]
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Build contracts
echo -e "${YELLOW}Building contracts${NC}"
forge build --silent
if [ $? -ne 0 ]; then
  echo -e "${RED}forge build failed${NC}"
  exit 1
fi

# Handle eip-1559 chains
readarray -t arr <"script/configs/networks-eip-1559"
echo -e "${YELLOW}Saving config for ${#arr[@]} chains: ${arr[@]}${NC}"
for chain in ${arr[@]}; do
  ./script/sh/router-config.sh $chain $1
done
# Handle legacy chains
readarray -t arr <"script/configs/networks-legacy"
echo -e "${YELLOW}Saving config for ${#arr[@]} chains: ${arr[@]}${NC}"
for chain in ${arr[@]}; do
  ./script/sh/router-config.sh $chain $1
done
