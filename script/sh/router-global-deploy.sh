#!/usr/bin/env bash
# This script will deploy SynapseRouter and its auxilary contracts on all chains specified in
# - "./script/networks-eip-1559"
# - "./script/networks-legacy"
# Deployment address on every chain will depend on the deployer address initial nonce.
# Existing deployments will be reused rather than overwritten.
# Usage: ./script/sh/router-global-deploy.sh [-b]

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

function deploy() {
  # deploy eip-1559|legacy true|false
  # Read the list of chains to deploy to
  readarray -t arr <script/networks-$1
  echo -e "${YELLOW}Will be deploying SynapseRouter on ${#arr[@]} $1 chains: ${arr[@]}${NC}"
  for chain in ${arr[@]}; do
    ./script/sh/router-deploy.sh $chain $1 $2
    if [ $? -ne 0 ]; then
      echo -e "${RED}Deployment on $chain failed${NC}"
      exit 1
    fi
  done
}

# Check if deploy transactions need to be broadcasted, or is this just a multi-chain simulation
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
deploy "eip-1559" $broadcasted
deploy "legacy" $broadcasted
