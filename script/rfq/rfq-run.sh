#!/usr/bin/env bash
# This script runs an RFQ script for all chains with FastBridge deployment
# Usage: ./script/rfq-run.sh pathToScript <args...>
# - ./script/run.sh pathToScript chain <args...> will be run for all RFQ chains

# Colors
RED="\033[0;31m"
NC="\033[0m" # No Color

scriptFN=$1
# Get the rest of the args
shift 1
# Check that all required args exist
if [ -z "$scriptFN" ]; then
  echo -e "${RED}Usage: ./script/rfq-run.sh pathToScript <args...>${NC}"
  exit 1
fi

./script/rfq/rfq-cmd.sh "./script/run.sh $scriptFN" "$@"
