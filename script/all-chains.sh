#!/usr/bin/env bash
# This script parses the list of chains from foundry.toml and runs a command for each chain
# Usage: ./script/all-chains.sh "<command>" [<args...>]
# - <command> chainName <args...> will be run for each chain

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
NC="\033[0m" # No Color

COMMAND=$1
# Get the rest of the args
shift 1
ARGS=$@
# Check that all required args exist
if [ -z "$COMMAND" ]; then
  echo -e "${RED}Usage: ./script/all-chains.sh \"<command>\" [<args...>]${NC}"
  exit 1
fi

# Get the list of chain aliases from foundry.toml
# Aliases are spicified after [rpc_endpoints] line:
# chainName = "${CHAIN_NAME_API}"
# List of aliases ends when next section is found (e.g. [etherscan])
# 1. We use sed to get the lines between [rpc_endpoints] and the next section
# 2. We use grep to ignore lines that start with [
# 3. We use cut to get the first part of each line before the first =
# 4. We use cut to get the first part of each line before the first space
# This gives us a list of chain aliases
CHAIN_ALIASES=$(cat foundry.toml | sed -n -e '/\[rpc_endpoints\]/,/^\[/p' | grep -v '^\[' | cut -d '=' -f1 | cut -d ' ' -f1)
# Print the comma separated list of chain aliases
PRETTY_CHAIN_ALIASES=$(echo $CHAIN_ALIASES | sed 's/ /, /g')
echo "Found chains: $PRETTY_CHAIN_ALIASES"
# Add space before args, if they are not empty (for pretty printing)
PRETTY_ARGS=""
if [ ! -z "$ARGS" ]; then
  PRETTY_ARGS=" $ARGS"
fi
echo -e "${GREEN}Running [$COMMAND <chainAlias>$PRETTY_ARGS] for each chain...${NC}"
# Loop through the chain aliases
for CHAIN_ALIAS in $CHAIN_ALIASES; do
  # Run the command for each chain
  $COMMAND $CHAIN_ALIAS $ARGS
done
