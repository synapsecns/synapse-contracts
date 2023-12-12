#!/usr/bin/env bash
# This script checks the CCTP deployment on a given chain
# Usage: ./script/cctp/check-chain.sh <chainName>

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
NC="\033[0m" # No Color

CHAIN_NAME=$1
if [ -z "$CHAIN_NAME" ]; then
  echo -e "${RED}Usage: ./script/cctp/check-chain.sh <chainName>${NC}"
  exit 1
fi

# Fetch the RPC URL for the chain from .env
source .env
# Check that RPC URL env var exists
CHAIN_RPC_ENV=${CHAIN_NAME^^}_API
CHAIN_RPC_URL=${!CHAIN_RPC_ENV}
if [ -z "$CHAIN_RPC_URL" ]; then
  echo -e "${RED}Error: $CHAIN_RPC_ENV env var not found${NC}"
  exit 1
fi
echo -e "${GREEN}Looking into SynapseCCTP deployment on $CHAIN_NAME${NC}"

# Get SynapseCCTP deployment address
artifactFN="deployments/$CHAIN_NAME/SynapseCCTP.json"
if [ ! -f "$artifactFN" ]; then
  echo -e "${RED}Error: $artifactFN not found${NC}"
  exit 1
fi
synapseCCTP=$(cat $artifactFN | jq -r '.address')
echo "  SynapseCCTP: $synapseCCTP"
owner=$(cast call -r $CHAIN_RPC_URL $synapseCCTP "owner()(address)")
echo "    Owner: $owner"

proxyAdminFN="deployments/$CHAIN_NAME/ProxyAdmin.SynapseCCTP.json"
if [ ! -f "$proxyAdminFN" ]; then
  echo -e "${RED}Error: $proxyAdminFN not found${NC}"
  exit 1
fi
proxyAdmin=$(cat $proxyAdminFN | jq -r '.address')

implementation=$(cast call -r $CHAIN_RPC_URL $proxyAdmin "getProxyImplementation(address)(address)" $synapseCCTP)
echo "    Implementation: $implementation"
admin=$(cast call -r $CHAIN_RPC_URL $proxyAdmin "getProxyAdmin(address)(address)" $synapseCCTP)
echo "    ProxyAdmin: $admin"
adminOwner=$(cast call -r $CHAIN_RPC_URL $admin "owner()(address)")
echo "      ProxyAdmin's owner: $adminOwner"
