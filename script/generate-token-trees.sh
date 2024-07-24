#!/usr/bin/env bash
# This script generates the token tree visualization for all linked pools
# Note: there are no transactions to broadcast
# Usage: ./script/generate-token-trees.sh

# Build the contracts first
forge build

# Find all config files. These are located in script/configs and have LinkedPool.*.dc.json name
configs=$(find script/configs -name "LinkedPool.*.dc.json")

for config in $configs; do
  # Config file has path script/configs/chainName/LinkedPool.symbol.dc.json
  # Extract chain name and symbol from the path
  chainName=$(echo "$config" | sed -n 's/.*configs\/\(.*\)\/LinkedPool\..*\.dc\.json/\1/p')
  symbol=$(echo "$config" | sed -n 's/.*LinkedPool\.\(.*\)\.dc\.json/\1/p')
  echo "Cleaning up token tree for $chainName $symbol"
  # Remove script/configs/chainName/LinkedPool.symbol.* files except the one we are processing,
  # e.g. remove script/configs/linea/LinkedPool.USDC.png but keep script/configs/linea/LinkedPool.USDC.dc.json
  find "script/configs/$chainName" -name "LinkedPool.$symbol.*" ! -name "LinkedPool.$symbol.dc.json" -exec rm {} \;
  forge script ./script/router/linkedPool/GenerateTokenTree.s.sol -f "$chainName" --sig "run(string)" "$symbol"
done
