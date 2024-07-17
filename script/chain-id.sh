#!/usr/bin/env bash
# This script fetches the cahin ID using cast and saves it to deployments/<chainName>/.chainId
# Usage: ./script/chain-id.sh <chainName>

# Colors
RED="\033[0;31m"
NC="\033[0m" # No Color

chainName=$1
# Check that chainName is passed
if [ -z "$chainName" ]; then
    echo -e "${RED}Usage: ./script/chain-id.sh <chainName>${NC}"
    exit 1
fi

# Fetch the RPC URL for the chain from .env
source .env
chainRpcEnv=${chainName^^}_API
chainRpc=${!chainRpcEnv}

# Create the deployments/<chainName> directory if it doesn't exist
mkdir -p "deployments/$chainName"
chainId=$(cast chain-id -r "$chainRpc")
# Print chainId without a newline
echo -n "$chainId" >"deployments/$chainName/.chainId"
