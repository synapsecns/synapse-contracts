#!/usr/bin/env bash
# This script verifies a deployed contract on the chain's block explorer
# Contract address and constructor arguments are fetched from deployments/<chainName>/<contractName>.json
# Usage: ./script/verify-contract.sh <chainName> <contractName> [<options...>]
# - <chainName> is the name of the chain, must match the name in foundry.toml AND deployments/<chainName>
# - <contractName> is the name of the contract, must match the name in deployments/<chainName>/<contractName>.json
# - <options> are the extra options to pass to `forge verify-contract` (could be omitted)

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
NC="\033[0m" # No Color

# Fetch the chain name and contract name
CHAIN_NAME=$1
CONTRACT_NAME=$2
# Check that all args exist
if [ -z "$CHAIN_NAME" ] || [ -z "$CONTRACT_NAME" ]; then
    echo -e "${RED}Usage: ./script/verify-contract.sh <chainName> <contractName> [<options...>]${NC}"
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

# Fetch the verifier options: verifier, verifier url, verifier key
VERIFIER_OPTIONS=""
source .env
# Etherscan? Try loading CHAIN_NAME_ETHERSCAN_URL env var
CHAIN_NAME_ETHERSCAN_URL_ENV=${CHAIN_NAME^^}_ETHERSCAN_URL
CHAIN_NAME_ETHERSCAN_URL=${!CHAIN_NAME_ETHERSCAN_URL_ENV}
if [ ! -z "$CHAIN_NAME_ETHERSCAN_URL" ]; then
    echo -e "${GREEN}Using Etherscan for verification${NC}"
    # CHAIN_NAME_ETHERSCAN_KEY env var needs to exist
    CHAIN_NAME_ETHERSCAN_KEY_ENV=${CHAIN_NAME^^}_ETHERSCAN_KEY
    CHAIN_NAME_ETHERSCAN_KEY=${!CHAIN_NAME_ETHERSCAN_KEY_ENV}
    if [ -z "$CHAIN_NAME_ETHERSCAN_KEY" ]; then
        echo -e "${RED}Error: $CHAIN_NAME_ETHERSCAN_KEY_ENV env var not found${NC}"
        exit 1
    fi
    # etherscan is the default verifier
    VERIFIER_OPTIONS="--verifier-url $CHAIN_NAME_ETHERSCAN_URL -e $CHAIN_NAME_ETHERSCAN_KEY"
else
    # Blockscout? Try loading CHAIN_NAME_BLOCKSCOUT_URL env var
    CHAIN_NAME_BLOCKSCOUT_URL_ENV=${CHAIN_NAME^^}_BLOCKSCOUT_URL
    CHAIN_NAME_BLOCKSCOUT_URL=${!CHAIN_NAME_BLOCKSCOUT_URL_ENV}
    if [ ! -z "$CHAIN_NAME_BLOCKSCOUT_URL" ]; then
        echo -e "${GREEN}Using Blockscout for verification${NC}"
        # No API key is needed for Blockscout
        VERIFIER_OPTIONS="--verifier blockscout --verifier-url $CHAIN_NAME_BLOCKSCOUT_URL"
    else
        # Use Sourcify as the last resort
        echo -e "${GREEN}Using Sourcify for verification${NC}"
        VERIFIER_OPTIONS="--verifier sourcify"
    fi
fi

# Fetch the contract address and constructor arguments
ARTIFACT_FILE="deployments/$CHAIN_NAME/$CONTRACT_NAME.json"
if [ ! -f "$ARTIFACT_FILE" ]; then
    echo -e "${RED}Error: contract artifact not found at $ARTIFACT_FILE${NC}"
    exit 1
fi
# Parse the artifact file
CONTRACT_ADDRESS=$(jq -r '.address' $ARTIFACT_FILE)
CONSTRUCTOR_ARGS=$(jq -r '.constructorArgs' $ARTIFACT_FILE)
# Check that the contract address exists (jq returns null if the key is not found)
if [ "$CONTRACT_ADDRESS" == "null" ]; then
    echo -e "${RED}Error: contract address not found in $ARTIFACT_FILE${NC}"
    exit 1
fi
# Assign 0x to the constructor args if they are empty
if [ "$CONSTRUCTOR_ARGS" == "null" ]; then
    CONSTRUCTOR_ARGS="0x"
fi

# Contract canonical name is everything preceding the first dot in the contract name
# Or the entire contract name if there is no dot
CONTRACT_CANONICAL_NAME=$(echo $CONTRACT_NAME | cut -d. -f1)
forge verify-contract $CONTRACT_ADDRESS $CONTRACT_CANONICAL_NAME \
    --chain $CHAIN_ID \
    $VERIFIER_OPTIONS \
    $FORGE_ARGS \
    --watch \
    --constructor-args $CONSTRUCTOR_ARGS
