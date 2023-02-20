#!/usr/bin/env bash
# This script check factory deployer nonces on all chains specified in "./script/configs/production-networks.txt".

function nonces() {
  # nonces eip-1559|legacy <address>
  readarray -t arr <"script/networks-$1"
  echo "Will be checking nonce on ${#arr[@]} $1 chains"
  for chain in ${arr[@]}; do
    nonce=$(cast nonce --rpc-url $chain $2) || exit 1
    printf "[%10s]: $nonce\n" $chain
  done
}

if [ -z "$1" ]; then
  echo "Error: Please provide a deployer address as an argument."
  exit 1
fi

nonces "eip-1559" $1
nonces "legacy" $1
