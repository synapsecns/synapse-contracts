#!/usr/bin/env bash
# Checks if the "fresh deployment" optimistically saved by a Foundry script at (notice the first dot)
# ".deployments/chain/contract.json" exists.
# If deployment succeeded, the artifact is moved to "deployments/chain/contract.json"
# Usage: ./script/sh/save-deployment.sh <chain> <contract>

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# First argument is the chain name
if [ -z "$1" ]; then
  echo -e "${RED}Error: Please provide a chain name as the first argument.${NC}"
  exit 1
elif [ ! -e "deployments/$1/.chainId" ]; then
  echo -e "${RED}Error: '$1' is not a valid chain name${NC}"
  exit 1
fi
# Second argument is contract name
if [ -z "$2" ]; then
  echo -e "${RED}Error: Please provide a contract name as the first argument.${NC}"
  exit 1
fi
# Derive where the "fresh deployment" is located
freshFN=".deployments/$1/$2.json"
if [ ! -e $freshFN ]; then
  echo -e "${RED}Fresh deployment for $2 on $1 does not exist${NC}"
  exit 1
fi
# Parse deployment address
address=$(jq .address $freshFN)
if [ $address == "null" ]; then
  echo -e "${RED}Skipping $2: no address found${NC}"
  exit
fi
# Remove double quotes
address=$(echo "$address" | tr -d '"')
# Derive RPC URL for the chain
source .env
rpcURL="rpc_"$1
rpcURL="${!rpcURL}"
if [ -z "$rpcURL" ]; then
  echo -e "${RED}Skipping $1: no RPC URL provided${NC}"
  exit
fi
echo -e "${YELLOW}Getting contract code for $2 on $1: $address${NC}"
# Check contract code
code=$(cast code --rpc-url $rpcURL $address)
# 0x is returned for an address without code
if [ ${#code} -le 2 ]; then
  echo -e "${RED}$2 has not been deployed on $1${NC}"
else
  echo -e "${GREEN}$2 has been deployed on $1${NC}"
  # Move deployment artifact to "verified deployments"
  mv $freshFN "deployments/$1/$2.json"
fi
