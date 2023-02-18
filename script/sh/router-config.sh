#!/usr/bin/env bash
# This script will save the deploy configuration for SynapseRouter and its auxilary contracts
# on the requested chain.
# Existing deploy configurations will not be overwritten unless expicitly instructed.

# Usage: ./script/sh/router-config.sh <chain> [--overwrite]

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# First argument is the chain name
if [ -z "$1" ]; then
  echo -e "${RED}Error: Please provide a chain name as the first argument.${NC}"
  exit 1
elif [ ! -e "deployments/$1/.chainId" ]; then
  echo -e "${RED}Error: '$1' is not a valid chain name${NC}"
  exit 1
fi

# Create a directory with chain's deploy configs if it doesn't exist
dirName="script/configs/$1"
if [ ! -d "$dirName" ]; then
  mkdir -p "$dirName"
fi

# Check if config already exists
configFN="script/configs/$1/SynapseRouter.dc.json"
if [ -e $configFN ]; then
  if [ "$2" != "--overwrite" ]; then
    echo -e "${GREEN}Config already exists on $1${NC}"
    exit
  fi
  echo -e "${YELLOW}Will be overwriting config for $1${NC}"
  rm $configFN
else
  echo -e "${YELLOW}Will be saving config for $1${NC}"
fi

# Save the config
forge script -f $1 script/router/SaveRouterConfig.s.sol
if [ $? -ne 0 ]; then
  echo -e "${RED}Failed to save config for $1${NC}"
else
  echo -e "${GREEN}Saved config for $1${NC}"
fi
