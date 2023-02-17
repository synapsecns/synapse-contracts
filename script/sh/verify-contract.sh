#!/usr/bin/env bash
# This script verifies a deployed contract on all producation chains

source .env

if [ -z "$1" ]; then
  echo "Error: Please provide a contract name as an argument."
  exit 1
fi
readarray -t arr <script/configs/production-networks.txt

echo "Will be veryfying contract on ${#arr[@]} chains"

for chain in ${arr[@]}; do
  chain_id=$(cat "deployments/$chain/.chainId")
  if [ -z "$chain_id" ]; then
    echo "Skipping $chain: no .chainId found"
    continue
  fi
  url="etherscan_"$chain"_url"
  url="${!url}"
  if [ -z "$url" ]; then
    echo "Skipping $chain: no URL provided"
    continue
  fi
  key="etherscan_"$chain"_key"
  key="${!key}"
  if [ -z "$key" ]; then
    echo "Skipping $chain: no KEY provided"
    continue
  fi
  deploymentFN="deployments/$chain/$1.json"
  if [ ! -e "$deploymentFN" ]; then
    echo "Skipping $chain: no deployment found at $deploymentFN"
    continue
  fi
  address=$(jq .address $deploymentFN)
  if [ $address == "null" ]; then
    echo "Skipping $chain: no address found"
    continue
  fi
  address=$(echo "$address" | tr -d '"')
  args=$(jq .constructorArgs $deploymentFN)
  if [ $args == "null" ]; then
    echo "Skipping $chain: no constructor args found"
    continue
  fi
  args=$(echo "$args" | tr -d '"')
  forge verify-contract --chain $chain_id --verifier-url $url --constructor-args $args --watch $address $1 $key
done
