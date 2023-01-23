#!/usr/bin/env bash
case "$1" in
"-b" | "-B" | "--broadcast")
  echo "Deploy tx WILL be broadcasted on all chains."
  deployArgs="--broadcast --verify"
  ;;
"")
  echo "Deploy tx WILL NOT be broadcasted on any chains."
  deployArgs="--sig 'runDry()'"
  ;;
*)
  echo "Unknown paratemer: $1"
  exit 1
  ;;
esac

readarray -t arr <script/configs/production-networks.txt

echo "Will be deploying factory on ${#arr[@]} chains"

for chain in ${arr[@]}; do
  echo "Deploying Factory on [$chain]"
  bash -x -c "forge script --silent -f $chain script/factory/DeployFactory.s.sol $deployArgs"
done
