#!/usr/bin/env bash

if [ -z "$1" ]; then
  echo "Error: Please provide a chain name as an argument."
  exit 1
fi
deployArgs="$2"
case "$2" in
"-b" | "-B" | "--broadcast")
  echo "Deploy tx WILL be broadcasted on chain."
  deployArgs="--broadcast --verify"
  ;;
"")
  echo "Deploy tx WILL NOT be broadcasted on-chain."
  ;;
*)
  echo "Unknown paratemer: $2"
  exit 1
  ;;
esac
echo "Initiated: SynapseRouter deploy on $1"

# Create a directory with chain's deploy configs if it doesn't exist
dirName="script/configs/$1"
if [ ! -d "$dirName" ]; then
  mkdir -p "$dirName"
fi

# First, fetch the deploy config from Ethereum's BridgeConfig
echo "Launching script to save deploy config"
# Break execution, if script failed
bash -x -c "forge script --silent -f $1 script/router/SaveRouterConfig.s.sol || exit 1"

# Then, launch the deploy script
echo "Launching script to deploy SynapseRouter"
bash -x -c "forge script --silent -f $1 script/router/DeployRouter.s.sol $deployArgs"
