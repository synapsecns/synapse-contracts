#!/usr/bin/env bash
# This script executes a Forge script, using the specified wallet for private keys management.
# Forge script is supposed to expose a `function run(string memory arg) external` for the execution.
# Usage: ./script/string-run.sh <stringArg> <path/to/script.s.sol> <chainName> <walletName> [<options...>]
# - <stringArg> is the string argument to pass to the script `run(string)` function
# - <path/to/script.s.sol> is the path to the script file to execute
# - <chainName> is the name of the chain, must match the name in foundry.toml AND deployments/<chainName>
# - <walletName> is the name of the wallet in .env file. Following env vars must exist:
#   - WALLET_TYPE: the type of the wallet. Supported values: "keystore", "ledger", "trezor"
#   - WALLET_JSON: the path to the keystore file (required if WALLET_TYPE is "keystore")
#   - WALLET_ADDR: the address of the wallet
# - <options> are the extra options to pass to `forge script` (could be omitted)
#   - --broadcast to broadcast the transaction
#   - --verify to attempt verification of the deployed contracts

# Colors
RED="\033[0;31m"
NC="\033[0m" # No Color

# Check that at least four arguments are passed
if [ $# -lt 4 ]; then
    echo -e "${RED}Usage: ./script/string-run.sh <stringArg> <path/to/script.s.sol> <chainName> <walletName> [<options...>]${NC}"
    exit 1
fi

# Fetch the string arg
STRING_ARG=$1
# Fetch the run.sh args
shift 1
RUN_ARGS="$@ --sig ""run(string)"" $STRING_ARG"

# Use generic run.sh script
./script/run.sh $RUN_ARGS
