#!/usr/bin/env bash
# This script runs an RFQ script for all chains with FastBridge deployment
# Usage: ./script/rfq-cmd.sh "<command>" <args..>
# - <command> chain <args...> will be run for all RFQ chains

# Colors
RED="\033[0;31m"
NC="\033[0m" # No Color

command=$1
# Get the rest of the args
shift 1
# Check that all required args exist
if [ -z "$command" ]; then
  echo -e "${RED}Usage: ./script/rfq-cmd.sh <command> <args...>${NC}"
  exit 1
fi

# Find all FastBridge.json files in ./deployments
fastBridgeDeployments=$(find ./deployments -name FastBridge.json)
# Extract chain name from the list of filenames, sort alphabetically
chainNames=$(echo "$fastBridgeDeployments" | sed 's/.*\/\(.*\)\/FastBridge.json/\1/' | sort)
# Print the comma separated list of chain aliases, don't put a comma after the last one
chainNamesFormatted=$(echo "$chainNames" | sed ':a;N;$!ba;s/\n/, /g')
echo "Running $command for chains: [$chainNamesFormatted]"

for chainName in $chainNames; do
  $command "$chainName" "$@"
done
