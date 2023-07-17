#!/usr/bin/env bash
# This script verifies a deployed contract on a given chain
# Usage: ./script/sh/verify-contract.sh <chainName> <contractName>

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

if [ -z "$1" ]; then
  echo -e "${RED}Error: Please provide a chain name as the first argument.${NC}"
  exit 1
fi
if [ -z "$2" ]; then
  echo -e "${RED}Error: Please provide a contract name as teh second argument.${NC}"
  exit 1
fi

source .env
chain_id=$(cat "deployments/$1/.chainId")
if [ -z "$chain_id" ]; then
  echo -e "${RED}Skipping $1: no .chainId found${NC}"
  exit
fi
url="etherscan_"$1"_url"
url="${!url}"
if [ -z "$url" ]; then
  echo -e "${RED}Skipping $1: no verifier URL provided${NC}"
  exit
fi
key="etherscan_"$1"_key"
key="${!key}"
if [ -z "$key" ]; then
  echo -e "${RED}Skipping $1: no verifier KEY provided${NC}"
  exit
fi
deploymentFN="deployments/$1/$2.json"
if [ ! -e "$deploymentFN" ]; then
  echo -e "${RED}Skipping $1: no deployment found at $deploymentFN${NC}"
  exit
fi
address=$(jq .address $deploymentFN)
if [ $address == "null" ]; then
  echo -e "${RED}Skipping $1: no address found${NC}"
  exit
fi
# Remove double quotes
address=$(echo "$address" | tr -d '"')
args=$(jq .constructorArgs $deploymentFN)
if [ $args == "null" ]; then
  echo -e "${YELLOW}No constructor args found for $2${NC}"
  args=""
else
  # Remove double quotes
  args=$(echo "$args" | tr -d '"')
  args="--constructor-args $args"
fi
echo -e "${YELLOW}Verifying $2 on $1: $address${NC}"
forge verify-contract --chain $chain_id --verifier-url $url $args --watch -e $key $address $2
if [ $? -ne 0 ]; then
  echo -e "${RED}Failed to verify $2 on $1${NC}"
else
  echo -e "${GREEN}Verified $2 on $1${NC}"
fi
