#!/usr/bin/env bash
# This script prints wallet's nonce and balance on the given chain
# Usage: ./script/sh/wallet.sh <chainName> <walletName>

# Colors
RED="\033[0;31m"
NC="\033[0m" # No Color

CHAIN_NAME=$1
# Convert the wallet env name to uppercase
WALLET_ENV_NAME=${2^^}
if [ -z "$CHAIN_NAME" ] || [ -z "$WALLET_ENV_NAME" ]; then
  echo -e "${RED}Usage: ./script/sh/wallet.sh <chainName> <walletName>${NC}"
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
# Check that wallet address env var exists
WALLET_ADDR_ENV_NAME=${WALLET_ENV_NAME}_ADDR
WALLET_ADDR=${!WALLET_ADDR_ENV_NAME}
if [ -z "$WALLET_ADDR" ]; then
  echo -e "${RED}Error: $WALLET_ADDR_ENV_NAME env var not found${NC}"
  exit 1
fi

balance=$(cast balance --ether --rpc-url $CHAIN_RPC_URL $WALLET_ADDR)
nonce=$(cast nonce --rpc-url $CHAIN_RPC_URL $WALLET_ADDR)
echo "Wallet $WALLET_ENV_NAME on $CHAIN_NAME"
echo "  balance: $balance"
echo "  nonce: $nonce"
