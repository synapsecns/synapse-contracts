#!/usr/bin/env bash
# This script deploys the SynapseBridge implementation on all chains
# Usage: ./script/bridge/deploy-implementation.sh <walletName> [<args...>]
# - <walletName> name of the wallet to use for deployment

# Colors
RED="\033[0;31m"
NC="\033[0m" # No Color

WALLET_NAME=$1
# Get the rest of the args
shift 1
# Check that all required args exist
if [ -z "$WALLET_NAME" ]; then
  echo -e "${RED}Usage: ./script/bridge/deploy-implementation.sh <walletName> [<args...>]${NC}"
  exit 1
fi

# Make sure the script is run from the root of the project
PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/../../ && pwd)
cd "$PROJECT_ROOT" || exit 1

# Run the script on all chains with SynapseBridge deployment
# Look within deployments/chainName for SynapseBridge.json
for chainName in $(ls deployments); do
  if [ -f "deployments/$chainName/SynapseBridge.json" ]; then
    ./script/run.sh ./script/bridge/DeploySynapseBridge.s.sol "$chainName" "$WALLET_NAME" "$@"
  fi
done
