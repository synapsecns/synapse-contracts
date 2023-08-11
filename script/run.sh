#!/usr/bin/env bash
# This script executes a Forge script, using the specified wallet for private keys management
# Usage: ./script/run.sh <path/to/script.s.sol> <chainName> <walletName> [<options...>]
# - <path/to/script.s.sol> is the path to the script file to execute
# - <chainName> is the name of the chain, must match the name in foundry.toml AND deployments/<chainName>
# - <walletName> is the name of the wallet in .env file. Following env vars must exist:
#   - WALLET_TYPE: the type of the wallet. Supported values: "keystore", "ledger", "trezor"
#   - WALLET_JSON: the path to the keystore file (required if WALLET_TYPE is "keystore")
#   - WALLET_ADDR: the address of the wallet
# - <options> are the extra options to pass to `forge script` (could be omitted)
#   - --sig "function(args)" [args] to execute script function rather than run()
#   - --broadcast to broadcast the transaction

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
NC="\033[0m" # No Color

# Fetch the script path, chain name, keystore env name
SCRIPT_PATH=$1
CHAIN_NAME=$2
# Convert the wallet env name to uppercase
WALLET_ENV_NAME=${3^^}
# Check that all mandatory args exist
if [ -z "$SCRIPT_PATH" ] || [ -z "$CHAIN_NAME" ] || [ -z "$WALLET_ENV_NAME" ]; then
    echo -e "${RED}Usage: ./script/run.sh <path/to/script.s.sol> <chainName> <walletName> [<options...>]${NC}"
    exit 1
fi
# Shift the arguments to pass the rest to `forge script`
shift 3
# Preserve the quotes in the options, useful for --sig "function(arguments)"
# https://stackoverflow.com/questions/10835933/how-can-i-preserve-quotes-in-printing-a-bash-scripts-arguments
FORGE_OPTIONS=${*@Q}

# Fetch the RPC URL for the chain from .env
source .env
CHAIN_RPC_ENV=${CHAIN_NAME^^}_API
CHAIN_RPC_URL=${!CHAIN_RPC_ENV}
if [ -z "$CHAIN_RPC_URL" ]; then
    echo -e "${RED}Error: $CHAIN_RPC_ENV env var not found${NC}"
    exit 1
fi

# Fetch the chain-specific options from "./script/networks.json"
# Check if json file exists
NETWORKS_JSON="./script/networks.json"
if [ ! -f "$NETWORKS_JSON" ]; then
    echo -e "${RED}Error: $NETWORKS_JSON not found${NC}"
    exit 1
fi
# Options are stored in the "forgeOptions" field for the chain
# TODO: more chains need --slow option
CHAIN_OPTIONS=$(jq -r ".forgeOptions.$CHAIN_NAME" $NETWORKS_JSON)
# Use empty string if no options are found
if [ "$CHAIN_OPTIONS" == "null" ]; then
    CHAIN_OPTIONS=""
fi

# Fetch the wallet options
WALLET_OPTIONS=""
source .env
WALLET_TYPE_ENV_NAME=${WALLET_ENV_NAME}_TYPE
WALLET_TYPE=${!WALLET_TYPE_ENV_NAME}
# Check if wallet type env var exists
if [ -z "$WALLET_TYPE" ]; then
    echo -e "${RED}Error: $WALLET_TYPE_ENV_NAME env var not found${NC}"
    exit 1
fi
# Check that wallet address env var exists
WALLET_ADDR_ENV_NAME=${WALLET_ENV_NAME}_ADDR
WALLET_ADDR=${!WALLET_ADDR_ENV_NAME}
if [ -z "$WALLET_ADDR" ]; then
    echo -e "${RED}Error: $WALLET_ADDR_ENV_NAME env var not found${NC}"
    exit 1
fi
# Check if wallet type is keystore
if [ "$WALLET_TYPE" == "keystore" ]; then
    # WALLET_JSON and WALLET_ADDR env vars need to exist
    WALLET_JSON_ENV_NAME=${WALLET_ENV_NAME}_JSON
    WALLET_JSON=${!WALLET_JSON_ENV_NAME}
    if [ -z "$WALLET_JSON" ]; then
        echo -e "${RED}Error: $WALLET_JSON_ENV_NAME env var not found${NC}"
        exit 1
    fi
    WALLET_OPTIONS="--keystore $WALLET_JSON --sender $WALLET_ADDR"
elif [ "$WALLET_TYPE" == "ledger" ] || [ "$WALLET_TYPE" == "trezor" ]; then
    # TODO: check that no more options are required
    WALLET_OPTIONS="--$WALLET_TYPE --sender $WALLET_ADDR"
else
    # Use interactive prompt for private key as the last resort
    WALLET_OPTIONS="-i 1 --sender $WALLET_ADDR"
fi

# Print information about the signer address
echo -e "${GREEN}Using $WALLET_ADDR [$WALLET_TYPE] as the signer address${NC}"
# Get the signer balance in Ether
BALANCE=$(cast balance --ether --rpc-url $CHAIN_RPC_URL $WALLET_ADDR)
# Get that signer nonce
NONCE=$(cast nonce --rpc-url $CHAIN_RPC_URL $WALLET_ADDR)
echo "  Signer balance: $BALANCE"
echo "  Signer nonce: $NONCE"

# Create directory for fresh deployments in case it doesn't exist
mkdir -p ".deployments/$CHAIN_NAME"

# Execute the script, print the command to sanity check the options
bash -x -c "forge script $SCRIPT_PATH \
    -f $CHAIN_NAME \
    $WALLET_OPTIONS \
    $CHAIN_OPTIONS \
    $FORGE_OPTIONS"
