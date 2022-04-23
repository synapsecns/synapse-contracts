#!/usr/bin/env bash

forge test --match-contract "FraxMovrTest" --fork-url https://moonriver.api.onfinality.io/public --fork-block-number 1730000 -vvvv
forge test --no-match-contract "FraxMovrTest" -vvvv