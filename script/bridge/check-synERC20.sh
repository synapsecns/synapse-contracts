#!/usr/bin/env bash
# Usage: ./script/bridge/check-synERC20.sh <symbol>

symbol=$1
# Check that all required args exist
if [ -z "$symbol" ]; then
  echo "Usage: ./script/bridge/check-synERC20.sh <symbol>"
  exit 1
fi
# Find all <symbol>.json files in ./deployments
deployments=$(find ./deployments -name "${symbol}.json")
# Extract chain name from the list of filenames, sort alphabetically
chainNames=$(echo "$deployments" | sed 's/.*\/\(.*\)\/'$symbol'.json/\1/' | sort)
# Print the comma separated list of chain aliases, don't put a comma after the last one
chainNamesFormatted=$(echo "$chainNames" | sed ':a;N;$!ba;s/\n/, /g')
echo "Checking $symbol on chains: [$chainNamesFormatted]"
# Run the script for each chain
for chainName in $chainNames; do
  forge script ./script/bridge/VerifySynapseERC20.s.sol -f "$chainName" --sig "run(string)" "$symbol"
done
