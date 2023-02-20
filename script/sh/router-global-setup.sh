#!/usr/bin/env bash
# This script will configure SynapseRouter and its auxilary contracts on all chains specified in
# - "./script/networks-eip-1559"
# - "./script/networks-legacy"
# If the existing deployments were previousy configured, only the neccesary updates will be performed.

# Usage: ./script/sh/router-global-setup.sh [-b]

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

function configure() {
  # configure eip-1559|legacy true|false
  # Read the list of chains to deploy to
  readarray -t arr <script/networks-$1
  echo -e "${YELLOW}Will be configuring SynapseRouter on ${#arr[@]} $1 chains: ${arr[@]}${NC}"
  for chain in ${arr[@]}; do
    ./script/sh/router-setup.sh $chain $1 $2
    if [ $? -ne 0 ]; then
      echo -e "${RED}Setup on $chain failed${NC}"
      exit 1
    fi
  done
}

# Check if setup transactions need to be broadcasted, or is this just a multi-chain simulation
case "$1" in
"-b" | "-B" | "--broadcast")
  broadcasted="true"
  ;;
"")
  broadcasted="false"
  ;;
*)
  echo "Unknown paratemer: $1"
  exit 1
  ;;
esac

# Build contracts
echo -e "${YELLOW}Building contracts${NC}"
forge build --silent
if [ $? -ne 0 ]; then
  echo -e "${RED}forge build failed${NC}"
  exit 1
fi
configure "eip-1559" $broadcasted
configure "legacy" $broadcasted
