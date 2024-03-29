#!/usr/bin/env bash
# This script saves bytecode for a contract into "./script/solc/<contract>.json"
# Usage: ./script/sh/solc.sh <contract>

YELLOW='\033[0;33m'
NC='\033[0m' # No Color

if [ -z "$1" ]; then
  echo -e "${RED}Error: Please provide a contract name as an argument.{NC}"
  exit 1
fi

echo -e "${YELLOW}Compiling $1${NC}"
# This might be a bit redacted
forge v 0x0000000000000000000000000000000000000000 $1 --show-standard-json-input >temp.in.json
solc --standard-json temp.in.json >temp.out.json
# Extract key for the needed contract
keyFilter="\"/$1.sol\""
key=$(jq ".contracts | keys[] | select(endswith($keyFilter))" temp.out.json)
# Get the bytecode
bytecode="0x"$(jq -r ".contracts.$key.$1.evm.bytecode.object" temp.out.json)
# Save the bytecode
jq -n ".bytecode = \"$bytecode\"" >script/solc/$1.json
# Clean temp files
rm temp.in.json
rm temp.out.json