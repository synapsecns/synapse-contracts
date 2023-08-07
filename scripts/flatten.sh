#!/usr/bin/env bash
# This script flattens Solidity contracts and saves them in ./flattened
# The existing content of ./flattened is removed
# This tool takes both globs and filenames as the list of arguments and flattens everything
# Usage: ./script/sh/flatten.sh contracts/**.sol contracts/client/TestClient.sol <...>

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Check if arguments were supplied
if [ $# -eq 0 ]; then
  echo -e "${RED}Error: provide globs/filenames of the contracts to flatten!${NC}"
  exit 1
fi

# First, we remove the existing flattened files
rm -rf ./flattened

# Track the amount of flattened files for the final report
count=0
# Then, we iterate over the supplied arguments
# If any argument was a glob, this will iterate over the files it specifies
for var in "$@"; do
  # Strip contract name "Abc.sol" from the path
  fn=$(basename "$var")
  # Flatten the file and save it in ./flattened
  # Make sure that flattened contracts base names are unique!
  forge flatten "$var" -o "./flattened/$fn"
  ((++count))
done

echo -e "${GREEN}Files flattened: $count${NC}"
