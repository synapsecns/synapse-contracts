#!/usr/bin/env bash
# This script verifies that a contract has been deployed on a chain by checking its code length
# Contract address is fetched from "fresh deployments" directory, which is ".deployments/<chainName>/<contractName>.json"
# Usage: ./script/save-deployment.sh <chainName> <contractName>
# - <chainName> is the name of the chain, must match the name in foundry.toml AND deployments/<chainName>
# - <contractName> is the name of the contract, must match the name in ".deployments/<chainName>/<contractName>.json"

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
NC="\033[0m" # No Color

# Fetch the chain name and contract name
CHAIN_NAME=$1
CONTRACT_NAME=$2
# Check that all args exist
if [ -z "$CHAIN_NAME" ] || [ -z "$CONTRACT_NAME" ]; then
    echo -e "${RED}Usage: ./script/save-deployment.sh <chainName> <contractName>${NC}"
    exit 1
fi
# Shift the arguments to pass the rest to `forge verify-contract`
shift 2
FORGE_ARGS=$@

# Fetch chain id from deployments/<chainName>/.chainId
CHAIN_ID_FILE="deployments/$CHAIN_NAME/.chainId"
if [ ! -f "$CHAIN_ID_FILE" ]; then
    echo -e "${RED}Error: chain ID not found at $CHAIN_ID_FILE${NC}"
    exit 1
fi
CHAIN_ID=$(cat $CHAIN_ID_FILE)

# Fetch the contract address and constructor arguments from "fresh deployment" artifact
ARTIFACT_FILE=".deployments/$CHAIN_NAME/$CONTRACT_NAME.json"
if [ ! -f "$ARTIFACT_FILE" ]; then
    echo -e "${RED}Error: contract artifact not found at $ARTIFACT_FILE${NC}"
    exit 1
fi
# Parse the artifact file
CONTRACT_ADDRESS=$(jq -r '.address' $ARTIFACT_FILE)
# Check that the contract address exists (jq returns null if the key is not found)
if [ "$CONTRACT_ADDRESS" == "null" ]; then
    echo -e "${RED}Error: contract address not found in $ARTIFACT_FILE${NC}"
    exit 1
fi

# Fetch the RPC URL for the chain from .env
source .env
CHAIN_RPC_ENV=${CHAIN_NAME^^}_API
CHAIN_RPC_URL=${!CHAIN_RPC_ENV}
if [ -z "$CHAIN_RPC_URL" ]; then
    echo -e "${RED}Error: $CHAIN_RPC_ENV env var not found${NC}"
    exit 1
fi

# Check contract code
CODE=$(cast code --rpc-url $CHAIN_RPC_URL $CONTRACT_ADDRESS)
# 0x is returned for an address without code
if [ ${#CODE} -le 2 ]; then
    echo -e "${RED}$CONTRACT_NAME has not been deployed on $CHAIN_NAME at $CONTRACT_ADDRESS${NC}"
else
    echo -e "${GREEN}$CONTRACT_NAME has been deployed on $CHAIN_NAME at $CONTRACT_ADDRESS${NC}"
    # Move deployment artifact to "verified deployments"
    mv $ARTIFACT_FILE "deployments/$CHAIN_NAME/$CONTRACT_NAME.json"
fi
