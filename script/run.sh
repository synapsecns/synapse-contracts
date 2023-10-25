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
YELLOW="\033[0;33m"
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
# Figure out if this is a broadcasted deployment script:
# 1. Check if the script file name starts with "Deploy"
IS_DEPLOY_SCRIPT=$(basename $SCRIPT_PATH | grep -c "^Deploy")
# 2. Check if --broadcast option is passed
IS_BROADCASTED=$(echo "$@" | grep -c "\-\-broadcast")
# 3. Multiply the two
IS_BROADCASTED_DEPLOYMENT=$((IS_BROADCASTED * IS_DEPLOY_SCRIPT))
# Check if --verify is not passed for the broadcasted deployment script
if [ "$IS_BROADCASTED_DEPLOYMENT" == "1" ] && [[ "$@" != *"--verify"* ]]; then
    # Add --verify option
    echo -e "${YELLOW}Deploy script: adding --verify for the broadcasting${NC}"
    set -- "$@" "--verify"
fi
# Wrap the options in quotes except ones starting with -
FORGE_OPTIONS=""
for arg in "$@"; do
    if [[ "$arg" == "-"* ]]; then
        FORGE_OPTIONS="$FORGE_OPTIONS $arg"
    else
        FORGE_OPTIONS="$FORGE_OPTIONS \"$arg\""
    fi
done

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

# Save current timestamp to check for new deployments later
TIMESTAMP=$(date +%s)

# Execute the script, print the command to sanity check the options
bash -x -c "forge script $SCRIPT_PATH \
    -f $CHAIN_NAME \
    $WALLET_OPTIONS \
    $CHAIN_OPTIONS \
    $FORGE_OPTIONS"

# Save new deployments if this is a broadcasted deployment script
if [ "$IS_BROADCASTED_DEPLOYMENT" == "1" ]; then
    # Check ".deployments/$CHAIN_NAME" for files created after the script execution
    NEW_DEPLOYMENTS=$(find ".deployments/$CHAIN_NAME" -type f -newermt "@$TIMESTAMP")
    # save-deployment.sh for each new deployment
    for deployment in $NEW_DEPLOYMENTS; do
        # Save the deployment
        echo -e "${YELLOW}Found new potential deployment: $deployment${NC}"
        # Extract the contract name: base name without extension.
        # Need to cut at the last dot in case the contract alias contains dots (e.g. LinkedPool.nUSD.json).
        deployment=$(basename $deployment)
        deployment=${deployment%.*}
        ./script/save-deployment.sh $CHAIN_NAME $deployment
    done
fi
