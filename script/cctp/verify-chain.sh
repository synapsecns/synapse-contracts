#!/usr/bin/env bash
# This script verifeis the CCTP deployments on a given chain
# Usage: ./script/cctp/verify-chain.sh <chainName>

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
NC="\033[0m" # No Color

CHAIN_NAME=$1
if [ -z "$CHAIN_NAME" ]; then
  echo -e "${RED}Usage: ./script/cctp/check-chain.sh <chainName>${NC}"
  exit 1
fi

./script/verify-contract.sh $CHAIN_NAME SynapseCCTP.Implementation
./script/verify-contract.sh $CHAIN_NAME ProxyAdmin.SynapseCCTP
./script/verify-contract.sh $CHAIN_NAME TransparentUpgradeableProxy.SynapseCCTP --compiler-version "0.8.17"
./script/verify-contract.sh $CHAIN_NAME SynapseCCTPRouter
