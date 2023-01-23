#!/usr/bin/env bash
if [ -z "$1" ]; then
  echo "Error: Please provide a deployer address as an argument."
  exit 1
fi
readarray -t arr <script/configs/production-networks.txt

echo "Will be checking nonce on ${#arr[@]} chains"

for chain in ${arr[@]}; do
  nonce=$(cast nonce --rpc-url $chain $1) || exit 1
  echo "Nonce on [$chain]: $nonce"
done
