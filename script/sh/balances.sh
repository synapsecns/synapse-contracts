#!/usr/bin/env bash
# This script checks address balance on all chains specified in
# - "./script/networks-eip-1559"
# - "./script/networks-legacy"

function balances() {
  # balances eip-1559|legacy <address>
  readarray -t arr <"script/networks-$1"
  echo "Will be checking balance on ${#arr[@]} $1 chains"
  for chain in ${arr[@]}; do
    balance=$(cast balance --rpc-url $chain $2) || exit 1
    balance=$(cast --from-wei $balance)
    printf "[%10s]: $balance\n" $chain
  done

}

if [ -z "$1" ]; then
  echo "Error: Please provide an address as an argument."
  exit 1
fi

balances "eip-1559" $1
balances "legacy" $1
