#!/usr/bin/env bash
# This script parses the list of CCTP chains from CCTP global config and runs a command for each chain
# Usage: ./script/cctp-chains.sh "<command>" [<args...>]
# - <command> chainName <args...> will be run for each CCTP chain

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
  echo -e "${RED}Usage: ./script/cctp-chains.sh \"<command>\" [<args...>]${NC}"
  exit 1
fi

# Get the list of chain aliases from CCTP global config
CCTP_CONFIG_FILE="script/configs/SynapseCCTP.chains.json"
if [ ! -f "$CCTP_CONFIG_FILE" ]; then
  echo -e "${RED}CCTP global config file not found: $CCTP_CONFIG_FILE${NC}"
  exit 1
fi
# Aliases are the keys of the .mainnet.domains object
CHAIN_ALIASES=$(cat $CCTP_CONFIG_FILE | jq -r '.mainnet.domains | keys[]')
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
